# Generated by Django 4.2.6 on 2023-10-21 13:21

from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='Server',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('ip', models.CharField(max_length=16, unique=True)),
                ('status', models.CharField(choices=[('INITATE', 'INITATE'), ('ERROR', 'ERROR'), ('UPDATING', 'UPDATING'), ('UPDATED', 'UPDATED')], default='INITATE', max_length=16)),
                ('update_date', models.DateTimeField(auto_now=True)),
                ('location', models.CharField(blank=True, default='None', max_length=16, null=True)),
            ],
        ),
    ]
