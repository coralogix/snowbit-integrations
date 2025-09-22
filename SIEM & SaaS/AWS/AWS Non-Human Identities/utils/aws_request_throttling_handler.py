from random import randint
from time import sleep
import botocore.exceptions as boto_exception


def handle_request(request_func):
    counter = 0
    limit = 5
    raised_exception = None
    while counter <= limit:
        try:
            return request_func()

        except boto_exception.ClientError as ex:
            exception_name = ex.response['Error']['Code']

            if exception_name == 'LimitExceededException':
                counter += 1
                exception_content = f"API call limit exceeded - retried {counter}/{limit}. {str(ex)}"
                print(f"WARNING 🟠 {handle_request.__qualname__}\n{exception_content}")
                sleep(randint(2, 5))
                raised_exception = ex

            elif exception_name == 'RequestLimitExceeded':
                exception_content = f"Encountered 'RequestLimitExceeded' exception - retry {counter}/{limit}. {str(ex)}"
                print(f"WARNING 🟠 {handle_request.__qualname__}\n{exception_content}")
                sleep(randint(5, 15))
                raised_exception = ex
            else:
                raise ex
    limit_exceeded_msg = f"Throttling retry limit of {limit} was exceeded. skipping request. {str(raised_exception)}"
    print(f"WARNING 🟠 {handle_request.__qualname__}\n{limit_exceeded_msg}")

    raise raised_exception
