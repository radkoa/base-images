FROM #{FROM}

# remove several traces of python
RUN apk del python*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# install python dependencies
RUN apk add --no-cache \
		gnupg \
		sqlite-libs \
		libssl1.0 \
		libffi \
		libbz2

# key 63C7CC90: public key "Simon McVittie <smcv@pseudorandom.co.uk>" imported
# key 3372DCFA: public key "Donald Stufft (dstufft) <donald@stufft.io>" imported
RUN gpg --keyserver keyring.debian.org --recv-keys 4DE8FF2A63C7CC90 \
	&& gpg --keyserver pgp.mit.edu  --recv-key 6E3CBCE93372DCFA \
	&& gpg --keyserver pgp.mit.edu --recv-keys 0x52a43a1e4b77b059

ENV PYTHON_VERSION #{PYTHON_VERSION}

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 10.0.1

ENV SETUPTOOLS_VERSION 34.3.3

# point Python at a system-provided certificate database. Otherwise, we might hit CERTIFICATE_VERIFY_FAILED.
# https://www.python.org/dev/peps/pep-0476/#trust-database
ENV SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt

# https://github.com/docker-library/python/issues/147
ENV PYTHONIOENCODING UTF-8

RUN set -x \
	&& buildDeps=' \
		curl \
	' \
	&& apk add --no-cache --virtual .build-deps $buildDeps \
	&& curl -SLO "#{BINARY_URL}" \
	&& echo "#{CHECKSUM}" | sha256sum -c - \
	&& tar -xzf "Python-$PYTHON_VERSION.linux-#{TARGET_ARCH}.tar.gz" --strip-components=1 \
	&& rm -rf "Python-$PYTHON_VERSION.linux-#{TARGET_ARCH}.tar.gz" \
	&& if [ ! -e /usr/local/bin/pip ]; then : \
		&& curl -SLO "https://raw.githubusercontent.com/pypa/get-pip/430ba37776ae2ad89f794c7a43b90dc23bac334c/get-pip.py" \
		&& echo "19dae841a150c86e2a09d475b5eb0602861f2a5b7761ec268049a662dbd2bd0c  get-pip.py" | sha256sum -c - \
		&& python get-pip.py \
		&& rm get-pip.py \
	; fi \
	&& pip install --no-cache-dir --upgrade --force-reinstall pip=="$PYTHON_PIP_VERSION" setuptools=="$SETUPTOOLS_VERSION" \
	&& [ "$(pip list |tac|tac| awk -F '[ ()]+' '$1 == "pip" { print $2; exit }')" = "$PYTHON_PIP_VERSION" ] \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& cd / \
	&& apk del .build-deps \
	&& rm -rf /usr/src/python ~/.cache

# install "virtualenv", since the vast majority of users of this image will want it
RUN pip install --no-cache-dir virtualenv

ENV PYTHON_DBUS_VERSION 1.2.4

# install dbus-python
RUN set -x \
	&& buildDeps=' \
		curl \
		build-base \
		dbus-dev \
		dbus-glib-dev \
	' \
	&& apk add --no-cache --virtual .build-deps $buildDeps \
	&& mkdir -p /usr/src/dbus-python \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz" -o dbus-python.tar.gz \
	&& curl -SL "http://dbus.freedesktop.org/releases/dbus-python/dbus-python-$PYTHON_DBUS_VERSION.tar.gz.asc" -o dbus-python.tar.gz.asc \
	&& gpg --verify dbus-python.tar.gz.asc \
	&& tar -xzC /usr/src/dbus-python --strip-components=1 -f dbus-python.tar.gz \
	&& rm dbus-python.tar.gz* \
	&& cd /usr/src/dbus-python \
	&& PYTHON=python#{PYTHON_BASE_VERSION} ./configure \
	&& make -j$(nproc) \
	&& make install -j$(nproc) \
	&& cd / \
	&& apk del .build-deps \
	&& apk add --no-cache dbus dbus-glib \
	&& rm -rf /usr/src/dbus-python

CMD ["echo","'No CMD command was set in Dockerfile! Details about CMD command could be found in Dockerfile Guide section in our Docs. Here's the link: http://docs.resin.io/deployment/dockerfile"]
