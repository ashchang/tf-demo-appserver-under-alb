#!/bin/bash

gunicorn -w 1 -b 0.0.0.0:5000 demo:app
# while true; do sleep 15 ; done