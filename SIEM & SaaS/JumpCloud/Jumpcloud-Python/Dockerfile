# Use the official Python image
FROM python:3.9

# Set the working directory inside the container
WORKDIR /app

# Copy the Python script to the container
COPY jc.py /app/main.py

# Install required dependencies
RUN pip install requests

# Set the entry point to run the script
ENTRYPOINT ["python", "main.py"]
