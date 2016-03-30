#!/bin/bash

# terminate the sox play process 

PID=`pidof play`
kill -SIGTERM $PID

