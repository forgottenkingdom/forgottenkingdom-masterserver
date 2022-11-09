FROM shabaw/love:latest AS build
RUN mkdir /usr/src/app
WORKDIR /usr/src/app
COPY . ./

CMD [ "love", "." ]
EXPOSE 8080