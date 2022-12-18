<# # THIS SCRIPT WAS CREATED BY IDAN MASHAAL #
+ This scripts pulls data from JumpCloud Directory Insights and pushes to a SIEM.
+ Requirements from a SIEM is that it has a REST API to push events in JSON Lines.
+ Use the timestamp field in SIEM configuration if necassary to modify name of field
+ JumpCloud Directory Insights for PAID accounts has 90 days history,
  for FREE accounts history is 15 days.
+ Only one instance of this script can be run at any given time using a simple file lock mechanism.
+ Config file is stateful and upon first run, the 'state' section will be added. This means that any
  subsequent runs of the script will bring the delta from the last time it ran.
#>
param (
    [Parameter()]
    [string]$config_file
)

<#
##########################################
# DO NOT CHANGE ANYTHING BELOW THIS LINE #
########################################## 
#>

<# 
Test if $config_file exists
#>
if ( -not (Test-Path $config_file) )
{
    Write-Output ""
    Write-Output "ERROR: Can't find the file '$config_file'"
    Write-Output ""
    Exit
}

# Creating a temp file, we will use it later for the lock file
$temp_file = New-TemporaryFile

# Check if Locked and exit if locked
$lock_file = Join-Path -Path $temp_file.DirectoryName -ChildPath ((Split-Path $config_file -Leaf) + ".lock")
$locked = ( $null -ne (Get-Item -Path $lock_file -ErrorAction SilentlyContinue) )
if ( $locked ) 
{
    Write-Output ""
    Write-Output "ERROR: Only One instance is allowed"
    Write-Output "Found lock file '$lock_file'"
    Get-Content $lock_file
    Write-Output ""
    Exit
}

# Create Lock using Config File name, if we can't lock we exit
$lock_file_debug_data = @{}
$lock_file_debug_data['debug_start_timestamp'] = [Xml.XmlConvert]::ToString($(get-date), [Xml.XmlDateTimeSerializationMode]::Utc)
Rename-Item -Path $temp_file.FullName -NewName $lock_file
$lock_file_debug_data | ConvertTo-Json | Out-File $lock_file -Force
Write-Output ""
Write-Output ("created lock_file: " + $lock_file)
Write-Output ("debug_start_timestamp: " + $lock_file_debug_data['debug_start_timestamp'])
$locked = ( $null -ne (Get-Item -Path $lock_file -ErrorAction SilentlyContinue) )
if ( -not $locked )
{
    Write-Output ""
    Write-Output "ERROR: Cant create lock file '$lock_file'"
    Write-Output "Make sure you have write permissions to this path"
    Write-Output ""
    Exit
}
Write-Output ("locked")

try
{
    <#
    Variables
    Note that config file headers are a PSCustomObject so it is necassery to convert it to a hashtable
    #>
    $ProgressPreference = "silentlyContinue"
    $config = Get-Content $config_file | ConvertFrom-Json
    $headers = @{}
    foreach( $property in $config.siem.headers.psobject.properties.name )
    {
        $headers[$property] = $config.siem.headers.$property
    }

    <# 
    Config file is stateful. If the script never ran, we don't have the start_time or end_time, so using the initial_days_back
    Converting all time to RFC3339-formatted UTC date using XmlConvert and adding it back to the Config object, it will be saved later.
    With PAID accounts you can go up to 90 days back (-90) - JumpCloud can change this behaviour.
    And with FREE Accounts you can go up to 15 days back (-15) - JumpCloud can change this behaviour.  
    #>
    $state_keys = $config.state.psobject.Properties | ForEach-Object { $_.Name }
    $start_time = New-Object System.Object
    $end_time = New-Object System.Object
    if ( ($state_keys -notcontains "start_time") -or ($state_keys -notcontains "end_time") )
    {
        $start_time = (Get-Date -AsUTC).AddDays($config.jumpcloud.initial_days_back)
        $start_time = [Xml.XmlConvert]::ToString($start_time, [Xml.XmlDateTimeSerializationMode]::Utc)
        $config | Add-Member -MemberType NoteProperty -Name 'state' -Value (New-Object PSCustomObject) -Force
    }
    else 
    {
        <#
        Adding 1 millisecond so no overlapping in time. Millisecond is the highest resolution time the Directory Insights API identifies.
        If adding 1 tick overlap will happend.
        #>
        $start_time = $config.state.start_time
        $end_time = $config.state.end_time
        $start_time = $end_time.AddMilliseconds(1)
        $start_time = [Xml.XmlConvert]::ToString($start_time, [Xml.XmlDateTimeSerializationMode]::Utc)
        $end_time = [Xml.XmlConvert]::ToString($end_time, [Xml.XmlDateTimeSerializationMode]::Utc)
    }

    $config.state | Add-Member -MemberType NoteProperty -Name 'start_time' -Value $start_time -Force
    Write-Output "directory insights data start time: $start_time"

    <#
    Connect to JumpCloud
    #>
    Connect-JCOnline $config.jumpcloud.api_key -force
    $lock_file_debug_data['debug_progress_timestamp'] = [Xml.XmlConvert]::ToString($(get-date), [Xml.XmlDateTimeSerializationMode]::Utc)
    $lock_file_debug_data | ConvertTo-Json | Out-File $lock_file

    <#
    Get the number of insights available. This is important because if the number is ZERO fetching insights will result in an error
    #>
    $insights_count = Get-JcSdkEventCount -Service:('all') -StartTime:($start_time)
    Write-Output ""
    Write-Output "insights_count: $insights_count"
    Write-Output ""
    $lock_file_debug_data['debug_progress_timestamp'] = [Xml.XmlConvert]::ToString($(get-date), [Xml.XmlDateTimeSerializationMode]::Utc)
    $lock_file_debug_data | ConvertTo-Json | Out-File $lock_file

    <#
    We have insights, lets work
    #>
    if ( ($null -ne $insights_count) -and ($insights_count -gt 0) )
    {
        <#
        Fetch all insights
        #>
        $insights = Get-JcSdkEvent -Service:('all') -StartTime:($start_time) -Sort:("ASC")
        
        <#
        Initialize variables
        #>
        $counter = 0
        $batch_start = 0
        $batch_number = 0
        $batch_size = $config.siem.batch_size
        $batch_delay = $config.siem.batch_delay_milliseconds
        $error_sending_to_siem = $false
        
        <#
        Iterate on all insights
        #>
        while ( $counter -lt $insights_count )
        {
            <#
            Initialize batch counters
            #>
            $batch_end = $batch_start + $batch_size
            $batch_number++
            $insights_in_batch = 0

            <# 
            We are building a batch body which is a string, since there may be many directory insights events
            a standard Array won't be scalable. There is an option to use a GenericList of PSCustomObjects or StringBuilder.
            If the SIEM supports 'json_lines' then StringBuilder is used.
            If the SIEM supports 'json_array' then GenericList of PSCustomObjects is used and then converted to JSON.
            #>
            $batch_body_sb = New-Object System.Text.StringBuilder
            $batch_body_gl = New-Object System.Collections.Generic.List[PSCustomObject]
            <#
            Start processing log messages in batch
            #>
            for ( $i = $batch_start ; $i -lt $batch_end ; $i++ )
            {
                $lock_file_debug_data['debug_progress_timestamp'] = [Xml.XmlConvert]::ToString($(get-date), [Xml.XmlDateTimeSerializationMode]::Utc)
                $lock_file_debug_data | ConvertTo-Json | Out-File $lock_file
                <#
                We receive an array of PSObjects and we don't want to modify the array, so each element we will copy.
                #>
                $insight = New-Object PSCustomObject
                $insight = $insights[$i].psobject.Copy()
                
                <#
                If the SIEM timestamp needs a new field name, we replace it
                #>
                if ( ($null -ne $config.siem.timestamp_field_name) -and ($null -ne $config.jumpcloud.timestamp_field_name) )
                {
                    if ( $config.siem.timestamp_field_name -ne $config.jumpcloud.timestamp_field_name )
                    {
                        $insight | Add-Member -MemberType NoteProperty -Name $config.siem.timestamp_field_name -Value $insight.timestamp -Force
                        $insight.psobject.Members.Remove($config.jumpcloud.timestamp_field_name)
                    }
                }

                <#
                Add custom log fields
                #>
                foreach( $log_field in $config.siem.custom_log_fields.psobject.properties.name )
                {
                    $insight | Add-Member -MemberType NoteProperty -Name $log_field -Value $config.siem.custom_log_fields.$log_field -Force
                }

                <#
                Convert the insight to JSON which is a string
                #>
                $json_insight = $insight | ConvertTo-Json -Depth $config.jumpcloud.json_depth -Compress
                
                <#
                Now we will append it as a new line it using String Builder
                Inside this comment block is commented out the verion of using Generic Lists
                #>
                if ( $config.siem.format -eq 'json_lines' )
                {
                    [void]$batch_body_sb.AppendLine($json_insight)
                }
                elseif ( $config.siem.format -eq 'json_array') 
                {
                    $batch_body_gl.Add($insight)
                }
                
                
                <#
                Increment counters, if we reached our insights_count it means we are done and breaking from this batch
                #>
                $insights_in_batch++
                $counter++
                if ( $counter -ge $insights_count )
                {
                    break
                }
            }

            <#
            Converting our batch_body object to string. In this comment block is the way of doing it using GenericList of Strings
            #>
            $batch_body_str = New-Object System.Object
            if ( $config.siem.format -eq 'json_lines' )
            {
                $batch_body_str = $batch_body_sb.ToString()
            }
            elseif ( $config.siem.format -eq 'json_array') 
            {
                $batch_body_str = $batch_body_gl | ConvertTo-Json -Depth $config.jumpcloud.json_depth -Compress
            }

            <# 
            Some debug output before we push to SIEM
            #>
            Write-Output ("---- batch_number: " + $batch_number + " | insights_in_batch: " + $insights_in_batch + " | debug_progress_timestamp: " + $lock_file_debug_data['debug_progress_timestamp'] + " ----")
            # Write-Output $batch_body_str

            <#
            Make the batch request to SIEM
            #>
            try 
            {
                [void](Invoke-RestMethod -SkipCertificateCheck -Uri $config.siem.url -method $config.siem.method -ContentType $config.siem.content_type -Headers $headers -Body $batch_body_str)
            } 
            catch 
            {
                $error_sending_to_siem = $true
                Write-Output "Batch $batch_number Exception Details:"
                Write-Output "* StatusCode:" $_.Exception.Response.StatusCode.value__ 
                Write-Output "* StatusDescription:" $_.Exception.Response.StatusCode
                Write-Output "* ErrorMessage:" $_.ErrorDetails.Message
                Write-Output ""
            }

            <#
            Modify the next batch and sleep a bit
            #>
            $batch_start = $batch_end
            Start-Sleep -Milliseconds $batch_delay
        }

        <#
        As we are done, we will add to the config file the 'end_time' property and backup the old file, 
        then overwriting our config file as it's stateful.
        #>
        if ($null -ne $insights[$counter - 1].timestamp)
        {
            $end_time = $insights[$counter - 1].timestamp
            $end_time = [Xml.XmlConvert]::ToString($end_time, [Xml.XmlDateTimeSerializationMode]::Utc)
        }
        <#
        Only if we did not encounter an error pushing to siem, we will update the state in config
        #>
        if ( -not $error_sending_to_siem )
        {
            Copy-Item $config_file -Destination "$config_file.old" -Force
            $config.state | Add-Member -MemberType NoteProperty -Name 'end_time' -Value $end_time -Force
            $config | ConvertTo-Json | Out-File $config_file -Force
        }
        Write-Output "directory insights data end time: $end_time"
    }
    $lock_file_debug_data['debug_end_timestamp'] = [Xml.XmlConvert]::ToString($(get-date), [Xml.XmlDateTimeSerializationMode]::Utc)
    Write-Output ("debug_end_timestamp: " + $lock_file_debug_data['debug_end_timestamp'])
    Write-Output ""
    $lock_file_debug_data | ConvertTo-Json | Out-File $lock_file
}
finally
{
    # Remove Temp File
    Remove-Item $temp_file -Force -ErrorAction SilentlyContinue

    # Remove lock
    if ( $null -ne $lock_file )
    {
        Remove-Item -Path $lock_file -Force
        Write-Output ("removed lock_file: " + $lock_file)
    }

    # Check if we succeeded
    $locked = ( $null -ne (Get-Item -Path $lock_file -ErrorAction SilentlyContinue) )
    if ( -not $locked )
    {
        Write-Output ("unlocked")
    }
}
