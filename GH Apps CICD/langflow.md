use python 3.12
git clone https://github.com/Azure-Samples/msdocs-python-flask-webapp-quickstart
python -m venv venv
python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -m flask run
pip install langflow --pre --force-reinstall
python -m langflow run
Build flow
Download flow JSON