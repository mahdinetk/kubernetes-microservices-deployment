FROM nginx

EXPOSE 80

COPY ./nginx.conf /etc/nginx/conf.d/default.conf

COPY ./index.html /usr/share/nginx/html/index.html
COPY ./register.html /usr/share/nginx/html/register.html
COPY ./users.html /usr/share/nginx/html/users.html
#COPY ./api/main.py /usr/share/nginx/html/users.html/api/main.py
#COPY ./api/requirements.txt /usr/share/nginx/html/users.html/api/requirements.txt
