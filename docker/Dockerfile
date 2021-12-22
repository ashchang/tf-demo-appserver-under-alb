FROM ubuntu:18.04

RUN apt-get update -q \
  && DEBIAN_FRONTEND=noninteractive apt-get install -qy python3 python3-pip \
  && pip3 install -U pip \
  && pip3 install flask requests gunicorn
ENV LC_ALL=C.UTF-8

ADD config.py demo.py /
ADD test.sh /
EXPOSE 5000

CMD ["/test.sh"]