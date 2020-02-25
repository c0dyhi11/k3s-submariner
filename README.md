# k3s-submariner
This repo contains terraform scripts to deploy k3s and submariner across the globe.

By default this will deploy five seperate k3s clusters using Packet's t1.small.x86 bare metal servers (Only $0.07/hr). It also reserves a single global IPv4 address to be used as a BGP anycast endpoint so anyone connecting to that IP address will be directed to the closest cluster to them.

Submariner allows all of the pods and services to connect to eachother across all of the other clusters.

I haven't setup the BGP anycast stuff yet. But I've fully automated the install of k3s and submariner.

## Prereqs
Downlaod and install Terraform as well as subctl. I'm too lazy to provider instructions for each of those at the moment.