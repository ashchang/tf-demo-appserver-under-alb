import json
import requests
from flask import Flask
from config import DevConfig

app = Flask(__name__)
app.config.from_object(DevConfig)

@app.route("/")
def hello():
    resp = requests.get('http://169.254.170.2/v2/metadata/').text
    hostname = json.loads(resp)["Containers"][0]['DockerId']
    return f"Hello {hostname}"

if __name__ == '__main__':
    app.run(host='0.0.0.0',port=5000)
