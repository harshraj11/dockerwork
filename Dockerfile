#pulling base os as Centos7 
FROM centos/s2i-core-centos7


RUN yum -y  update

RUN yum -y install net-tools

#installing wget
RUN yum -y install wget

#installing Java 8
RUN yum -y install java-1.8.0-openjdk-devel
RUN java -version

#installing Python3
RUN yum -y install python3
RUN python3 --version

#installing perl
RUN yum -y install perl
RUN perl -V:version

#Copying JDBC and ODBC Drivers from host system
COPY ojdbc8.jar .
COPY postgresql-42.2.12.jar .

#installing pip3 for installing python3 packages
RUN python3.6 -m ensurepip
RUN pip3 --version

#setting the environment variable for tomcat installation files
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH

#creating the folder for tomcat installation files
RUN mkdir -p "$CATALINA_HOME"

#downloading tomcat 8
RUN wget https://mirrors.estointernet.in/apache/tomcat/tomcat-8/v8.5.56/bin/apache-tomcat-8.5.56.tar.gz

#extracting tomcat into the folder
RUN tar xvf apache-tomcat-8.5.56.tar.gz -C ${CATALINA_HOME} --strip-components=1

#installing supervisor
RUN pip3 install supervisor


#_________________________________________________________________________________________________________

#Oracle CLient Installation

COPY ./oracle /tmp/oracle
RUN yum install -y /tmp/oracle/oracle-instantclient19.6-basic-19.6.0.0.0-1.x86_64.rpm\
                   /tmp/oracle/oracle-instantclient19.6-sqlplus-19.6.0.0.0-1.x86_64.rpm\
                   /tmp/oracle/oracle-instantclient19.6-devel-19.6.0.0.0-1.x86_64.rpm\
    && sh -c "echo /usr/lib/oracle/19.6/client64/lib > /etc/ld.so.conf.d/oracle-instantclient.conf" && ldconfig\
    && rm -rf /tmp/oracle
ENV PATH /usr/lib/oracle/19.6/client64/bin:$PATH

#___________________________________________________________________________________________________________



#Creating environment variable for Postgres
ENV POSTGRESQL_VERSION=9.6 \
    POSTGRESQL_PREV_VERSION=9.5 \
    HOME=/var/lib/pgsql \
    PGUSER=postgres \
    APP_DATA=/opt/app-root

ENV SUMMARY="PostgreSQL is an advanced Object-Relational database management system" \
    DESCRIPTION="PostgreSQL is an advanced Object-Relational database management system (DBMS). \
The image contains the client and server programs that you'll need to \
create, run, maintain and access a PostgreSQL DBMS server."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="PostgreSQL 9.6" \
      io.openshift.expose-services="5432:postgresql" \
      io.openshift.tags="database,postgresql,postgresql96,rh-postgresql96" \
      io.openshift.s2i.assemble-user="26" \
      name="centos/postgresql-96-centos7" \
      com.redhat.component="rh-postgresql96-container" \
      version="9.6" \
      usage="docker run -d --name postgresql_database -e POSTGRESQL_USER=user -e POSTGRESQL_PASSWORD=pass -e POSTGRESQL_DATABASE=db -p 5432:5432 centos/postgresql-96-centos7"   

EXPOSE 5432

#copying the permission script
COPY root/usr/libexec/fix-permissions /usr/libexec/fix-permissions

#installing postgres
RUN yum install -y centos-release-scl-rh && \
    INSTALL_PKGS="rsync tar gettext bind-utils nss_wrapper rh-postgresql96 rh-postgresql96-postgresql-contrib rh-postgresql96-syspaths rh-postgresql95-postgresql-server" && \
    yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum -y clean all --enablerepo='*' && \
    localedef -f UTF-8 -i en_US en_US.UTF-8 && \
    test "$(id postgres)" = "uid=26(postgres) gid=26(postgres) groups=26(postgres)" && \
    mkdir -p /var/lib/pgsql/data && \
    /usr/libexec/fix-permissions /var/lib/pgsql /var/run/postgresql
    
#path for postgres installation files
ENV CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/postgresql \
    ENABLED_COLLECTIONS=rh-postgresql96

COPY root /
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

ENV BASH_ENV=${CONTAINER_SCRIPTS_PATH}/scl_enable \
    ENV=${CONTAINER_SCRIPTS_PATH}/scl_enable \
    PROMPT_COMMAND=". ${CONTAINER_SCRIPTS_PATH}/scl_enable"

#changing the owner of tomcat directory from user root to user postgres  
RUN chown -RH postgres: ${CATALINA_HOME}
RUN sh -c 'chmod +x ${CATALINA_HOME}'
RUN id -u postgres

RUN usermod -a -G root postgres && \
    /usr/libexec/fix-permissions --read-only "$APP_DATA"

 
EXPOSE 8009

#Copying requirements.txt file from host system
COPY requirements.txt .
#installing python packages
RUN pip3 install -r requirements.txt

RUN pip3 install psycopg2==2.7.5 --ignore-installed

#working directory for tomcat
WORKDIR ${CATALINA_HOME}

USER 26



ADD supervisor.conf /etc/supervisor.conf
CMD ["supervisord", "-c", "/etc/supervisor.conf"]
