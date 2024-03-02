FROM python:3.8-slim-bullseye
LABEL Odoo S.A. <info@odoo.com>

# Enable Odoo user and filestore
RUN useradd -md /home/odoo -s /bin/false odoo \
    && mkdir -p /var/lib/odoo \
    && chown -R odoo:odoo /var/lib/odoo \
    && mkdir -p /opt/odoo/src \
    && chown -R odoo:odoo /opt/odoo \
    && sync

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        python3-num2words \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.buster_amd64.deb \
    && echo 'ea8277df4297afc507c61122f3c349af142f31e5 wkhtmltox.deb' | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb \
    && apt-get install nodejs npm -y

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

# ==> Install CA INVAP
RUN curl -s http://pki.invap.com.ar/rootca/INVAPRootCA.crt -o INVAPRootCA.crt
RUN openssl x509 -in INVAPRootCA.crt -inform DER -outform PEM -out /usr/local/share/ca-certificates/INVAPRootCA_PEM.crt
RUN update-ca-certificates --verbose


RUN apt-get update && apt-get install -y procps
# <== Install CA INVAP

# Custom packages
RUN apt-get update \
    && apt-get install -y \
        libcups2-dev \
        libcurl4-openssl-dev \
        parallel \
        python3-dev \
        libevent-dev \
        libxml2-dev \
        libxslt1-dev \
        swig \
        git \
    # upgrade pip
    && pip install --upgrade pip
    # pip dependencies that require build deps
RUN pip install --no-cache-dir \
        git-aggregator==2.1.0 \
        # por problema con cryptography y pyOpenSSL replicamos lo que teniamos
        pyOpenSSL==19.0.0 \
        cryptography==35.0.0 \
        psycopg2-binary==2.8.6 \
        Werkzeug==2.0.2 \
        MarkupSafe==2.1.2 \
        passlib==1.7.4 \
        ## ingadhoc/odoo-argentina
        # forzamos version httplib2==0.20.4 porque con lanzamiento de 0.21 (https://pypi.org/project/httplib2/#history) empezo a dar error de ticket 56946
        httplib2==0.20.4 \
        git+https://github.com/pysimplesoap/pysimplesoap@a330d9c4af1b007fe1436f979ff0b9f66613136e \
        git+https://github.com/ingadhoc/pyafipws@py3k \
        ## ingadhoc/aeroo
        # use this genshi version to fix error when, for eg, you send arguments like "date=True" check this  \https://genshi.edgewall.org/ticket/600
        genshi==0.7.7 \
        git+https://github.com/adhoc-dev/aeroolib@master-fix-ods \
        git+https://github.com/aeroo/currency2text.git \
        pycups==2.0.1 \
        # date_range
        odoo-test-helper==2.0.2 \
        # varios
        algoliasearch==2.6.2 \
        pycurl==7.45.1 \
        email-validator==1.3.0 \
        unrar==0.4 \
        mercadopago==2.2.0 \
        # geoip
        geoip2==4.6.0 \
        pdf417gen==0.7.1 \
        PyPDF2 \
    && apt-get purge -yqq build-essential '*-dev' make || true \
    && apt-get -yqq autoremove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Include custom modules and external repositories
USER odoo
COPY --chown=odoo:odoo ./custom_modules/ /opt/odoo/src/custom-addons
COPY --chown=odoo:odoo repos.yaml /opt/odoo/

# get repositories with git aggregate
WORKDIR /opt/odoo/src
ARG GITHUB_BOT_TOKEN
ENV GITHUB_BOT_TOKEN="$GITHUB_BOT_TOKEN"
RUN gitaggregate -c /opt/odoo/repos.yaml --expand-env
USER root
WORKDIR /opt/odoo/

# Install Odoo
ARG ODOO_VERSION=16.0
ARG ODOO_SOURCE=odoo/odoo
ENV ODOO_VERSION="$ODOO_VERSION"
ENV ODOO_SOURCE="$ODOO_SOURCE"
# Install Odoo hard & soft dependencies, and Doodba utilities
# Falta      \
RUN build_deps=" \
        build-essential \
        libfreetype6-dev \
        libfribidi-dev \
        libghc-zlib-dev \
        libharfbuzz-dev \
        libjpeg-dev \
        liblcms2-dev \
        libldap2-dev \
        libopenjp2-7-dev \
        libsasl2-dev \
        libtiff5-dev \
        libwebp-dev \
        tcl-dev \
        tk-dev \
        zlib1g-dev \
    " \
    && apt-get update \
    && apt-get install -yqq --no-install-recommends $build_deps 

# Realizo n grep de requeriments.txt eliminando lineas porque tanto psycopg2, como  python-ldap requieren
# ser compliladas al instalarse y para poder hacerlo en la imagen pura de debian tenemos que agregar varias cosas.
# el workarround que usamos es instalar psycopg2-binary via pip y evitarnos ese problema
RUN  grep -v '^psycopg2'  /opt/odoo/odoo/requirements.txt  | grep -v '^python-ldap' > /opt/odoo/requirements.txt \
    && pip install  --no-cache-dir -r /opt/odoo/requirements.txt \
        ipython==8.7.0 \
        pdfminer.six==20220319 \
        pysnooper==1.1.1 \
        ipdb==0.13.9 \
        git+https://github.com/OCA/openupgradelib.git \
        click-odoo-contrib==1.16.1 \
        pg-activity==3.0.1 \
        phonenumbers==8.13.1 \
    && python3 -m compileall -q /usr/local/lib/python3.10/ || true \
    && apt-get purge -yqq $build_deps \
    && apt-get autopurge -yqq \
    && rm -Rf /var/lib/apt/lists/* /tmp/*

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY --chown=odoo:odoo ./odoo.conf /opt/odoo/

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
#RUN chown -R odoo.odoo /opt/odoo && sync

RUN mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8072

# Set the default config file
ENV ODOO_RC /opt/odoo/odoo.conf

COPY --chown=odoo:odoo wait-for-psql.py /usr/local/bin/
COPY --chown=odoo:odoo auto-detect-addons.py /usr/local/bin/

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]


USER odoo
