FROM ruby:2.7
MAINTAINER massimo@it20.info

################## BEGIN INSTALLATION ######################

# Set the working directory to /app
WORKDIR /app

COPY *.rb ./
COPY Gemfile Gemfile
COPY modules modules

ENV LANG=en_us.UTF-8
ENV LC_ALL=C.UTF-8
ENV RACK_ENV=production

RUN gem install sinatra --no-document
RUN gem install redis -v 4.8.1 --no-document
### hack to allow the setup of the pg gem (which would fail otherwise)
### end of hack (this would require additional research and optimization)
RUN gem install pg -v 1.5.9 --no-document
### this installs the AWS SDK for DynamoDB (so that appserver can talk to DDB Vs the default Postgres/Redis)
RUN gem install aws-sdk-dynamodb --no-document
# Set the working directory to /
WORKDIR /
ADD startup.sh startup.sh

# Lambda adapter
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.5.1 /lambda-adapter /lambda-adapter

# Setup Lambda RIE + RIC
RUN curl -L -o /usr/bin/lambda_rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/download/v1.9/aws-lambda-rie-x86_64
RUN chmod +x /usr/bin/lambda_rie
RUN gem install aws_lambda_ric -v 2.0.0 --no-document
RUN gem install 'rackup:2.2.1' 'puma:6.6.1' --no-document

##################### INSTALLATION END #####################

CMD ["./startup.sh"]


