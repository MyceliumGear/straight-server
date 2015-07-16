FROM ruby_base

ADD . /home/app/src
RUN chown -R app: /home/app

WORKDIR /home/app/src
USER app
