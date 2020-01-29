# Adapted from https://hub.docker.com/r/zlskidmore/varscan/dockerfile
# and https://medium.com/@chadlagore/conda-environments-with-docker-82cdc9d25754
FROM continuumio/miniconda3

MAINTAINER Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>

RUN conda create -n env python=3.6
RUN echo "source activate env" > ~/.bashrc
ENV PATH /opt/conda/envs/env/bin:$PATH

WORKDIR /opt
# https://github.com/geerlingguy/ansible-role-java/issues/64
RUN mkdir -p /usr/share/man/man1    

# run update
RUN apt-get update -y && apt-get install -y \
    curl \
    default-jdk \
    libnss-sss \
    parallel \
    vim 

# RUN printf 'will cite\n' | parallel --citation
RUN conda install -c bioconda bcftools samtools

# download varscan and change permissions
RUN cd /opt && wget https://sourceforge.net/projects/varscan/files/VarScan.v2.3.8.jar 

COPY . /opt/Varscan_GermlineCaller


