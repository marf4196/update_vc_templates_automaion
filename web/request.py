import requests

url = 'http://127.0.0.1:8000/api/v1/'

data = {
    'api_key': 'a3Bc4D5eF6g7H8i9J0kL1mN2oP3',
    'ip' : '192.168.1.1',
    'status' : 'INITIATE',
}

x = requests.post(url, data=data)

print(x.text)