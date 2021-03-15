FROM registry.access.redhat.com/ubi8/ubi-minimal

EXPOSE 8080

ENV PATH=$HOME/.local/bin/:$PATH \
    APP_ROOT=/opt/app-root \
    APP_CONFIG=/opt/app-root/src/rbac/gunicorn.py \
    APP_HOME=/opt/app-root/src/rbac \
    APP_MODULE=rbac.wsgi \
    APP_NAMESPACE=rbac

ENV SUMMARY="Insights RBAC is a role based access control web server" \
    DESCRIPTION="Insights RBAC is a role based access control web server"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="insights-rbac" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="python,python36,rh-python36" \
      com.redhat.component="python36-docker" \
      name="insights-rbac" \
      version="1" \
      maintainer="Red Hat Insights"

USER root

RUN microdnf install -y make nodejs python36
RUN pip3 install pipenv
RUN npm install -g apidoc

# Copy config files to the image.
COPY openshift/root /

# Copy application files to the image.
COPY . ${APP_ROOT}/src
WORKDIR ${APP_ROOT}/src

RUN pipenv install --deploy --ignore-pipfile --system --verbose

RUN make gen-apidoc
RUN python3 ${APP_HOME}/manage.py collectstatic --noinput
# - In order to drop the root user, we have to make some directories world
#   writable as OpenShift default security model is to run the container
#   under random UID.
RUN chown -R 1001:0 ${APP_ROOT}

RUN curl -L -o /usr/bin/haberdasher \
https://github.com/RedHatInsights/haberdasher/releases/latest/download/haberdasher_linux_amd64 && \
chmod 755 /usr/bin/haberdasher

USER 1001

ENTRYPOINT ["/usr/bin/haberdasher"]

CMD $APP_ROOT/src/openshift/s2i/bin/run
