#!/bin/bash

docker run --name imaginary --rm -p 9000:9000 -v thumbnails:/mnt/data imeoer/imaginary -cors -enable-url-source -http-cache-ttl 31556926 -mount /mnt/data
