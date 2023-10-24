from django.shortcuts import render
from django.http import HttpResponse, Http404
from django.views.decorators.csrf import csrf_exempt
from web.settings import API_KEY
from .models import Server
import json

@csrf_exempt
def IndexView(request):
    if request.method == 'POST':
        data = json.loads(request.body)
        api_key = data['api_key']
        if api_key == API_KEY:
            ip = data['ip']
            status = data['status']
            try:
                server = Server.objects.get(ip = ip)
            except:
                raise Http404("Coult not find the server")
            server.status = status
            server.save()
            return HttpResponse(request.POST.items())
        else:
            print('here')
            raise PermissionError 
    else:
        return HttpResponse('GET')
