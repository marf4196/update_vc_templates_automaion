from django.shortcuts import render
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def IndexView(request):
    if request.method == 'POST':
        data = request.POST.get('title')
        return HttpResponse(f'POST: {data}')
    else:
        return HttpResponse('GET')