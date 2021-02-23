FROM amazonlinux
RUN yum install jq -y
ADD startup.sh /test/startup.sh
ENTRYPOINT ["/test/startup.sh"]
