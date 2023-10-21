from django.urls import path
from .v1 import IndexView

app_name = 'api'

urlpatterns = [
    path('v1/', IndexView, name='IndexView')
]