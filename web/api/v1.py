from django.shortcuts import render
from django.http import HttpResponse, Http404
from django.views.decorators.csrf import csrf_exempt
from web.settings import API_KEY
from models import Server

@csrf_exempt
def IndexView(request):
    if request.method == 'POST':
        api_key = request.POST.get('api_key')
        if api_key == API_KEY:
            ip = request.POST.get('ip')
            status = request.POST.get('status')
            try:
                server = Server.objects.get(ip = ip)
            except:
                raise Http404("Coult not find the server")
            server.status = status
            server.save()
            return HttpResponse(request.POST.items())
        else:
            raise PermissionError 
    else:
        return HttpResponse('GET')