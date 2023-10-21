import requests

url = 'http://127.0.0.1:8000/api/v1/'

data = {
    'title': 'data',
}

x = requests.post(url, data=data)

print(x.text)