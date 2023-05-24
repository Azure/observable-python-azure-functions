import json
import uuid
import os
import glob
import logging
from argparse import ArgumentParser
from dotenv import load_dotenv

from azure.cosmos import CosmosClient


parser = ArgumentParser()
parser.add_argument(
    "-d", "--directory", dest="directory", help="Directory containing json files to upload", default="data"
)

parser.add_argument(
    "-e", "--env-file", dest="envfile", help="path to file contain environment variables", default="config/.env"
)
args = parser.parse_args()

path_env_file = args.envfile
if not load_dotenv(path_env_file):
    raise Exception(f"Can not access {path_env_file} from script")

try:
    cosmos_connection_string = os.environ['COSMOSDB_CONNECTION_STRING']
except Exception as e:
    raise e

path = args.directory[:-1] if args.directory[-1] == '/' else args.directory
path_json_files = f"{path}/*.json"

json_files = glob.glob(path_json_files)

try:
    client = CosmosClient.from_connection_string(cosmos_connection_string)
    database = client.get_database_client("ContosoDatabase")
    container = database.get_container_client("onPremisesData")
except Exception as e:
    logging.exception(e)
    raise e

for json_file in json_files:
    try:
        with open(json_file,encoding="utf-8") as f:
            body_to_upload = json.load(f)
            container.upsert_item(body=body_to_upload)
    except Exception as e:
        raise Exception("Error inserting to db") from e
