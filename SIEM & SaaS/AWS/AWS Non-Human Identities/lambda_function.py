from main import NonHumanIdentities


def lambda_handler(event, context):
    NonHumanIdentities().run()
