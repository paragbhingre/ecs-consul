FROM amazonlinux
RUN yum install jq -y
ADD init.sh /test/init.sh
ENTRYPOINT ["/test/init.sh"]