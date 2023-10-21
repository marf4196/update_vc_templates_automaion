from django.db import models

# Create your models here.

class Server(models.Model):
    server_status = (
        ('INITATE', 'INITATE'),
        ('ERROR', 'ERROR'),
        ('UPDATING', 'UPDATING'),
        ('UPDATED', 'UPDATED')
    )
    ip = models.CharField(max_length=16, null=False, blank=False, unique=True)
    status = models.CharField(max_length=16, null=False, blank=False, unique=False, choices=server_status, default='INITATE')
    update_date = models.DateTimeField(auto_now=True)
    location = models.CharField(max_length=32, null=True, blank=True, default=None)

    def __str__(self):
        return self.ip