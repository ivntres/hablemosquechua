Twit = Npm.require 'twit'

Meteor.startup ->
  serviceCredentials = Accounts.loginServiceConfiguration.findOne service: 'twitter'
  if serviceCredentials
    TweetCron = new Cron()
    TweetCron.addJob 1, -> # every minute
      date = moment()
      date.seconds 0
      date.milliseconds 0
      date = moment date.format( 'YYYY-MM-DD HH:mm:ss.SSS' )
      fechaHora = date.toDate()

      tweets = Tweets.find( fechaHora: fechaHora ).fetch()
      if tweets and not _(tweets).isEmpty()
        _(tweets).each (t) ->
          accessCredentials = Meteor.users.findOne( t.userId )?.services?.twitter
          if accessCredentials
            logger.info 'INFO: tuitenado'
            logger.info t.tweet
            twitter = new Twit
              consumer_key:        serviceCredentials.consumerKey
              consumer_secret:     serviceCredentials.secret
              access_token:        accessCredentials.accessToken
              access_token_secret: accessCredentials.accessTokenSecret

            twitter.post 'statuses/update', { status: t.tweet },
              Meteor.bindEnvironment( (err, response) ->
                if err
                  logger.error err
                  Tweets._collection.update t._id,
                    $set:
                      status: Tweets.STATUS.ERROR
                      twitterError: err
                else if response
                  Tweets._collection.update t._id,
                    $set:
                      status: Tweets.STATUS.SUCCESS
                      twitterResponse: response
                  if t.esRespuesta
                    palabra = PalabrasDiccionario.findOne t.palabraId
                    pregunta = Preguntas.findOne t.preguntaId
                    if pregunta.felicitacion
                      logger.info 'Buscando usuarios a felicitar'
                      usersStr = ""
                      fechaDesde = moment t.fechaHora
                      fechaDesde.subtract 'minutes', ( pregunta.delayRespuesta or 3 )

                      followersCorrectos = []
                      RespuestasCorrectas.find(
                        fechaHora: { $gt: fechaDesde.toDate() }
                        palabraId: t.palabraId
                      ).forEach (rc) ->
                        logger.info "Respuesta correcta de #{rc.userRespuesta}"
                        followersCorrectos.push rc.userRespuesta

                      aFelicitar = Followers.find screenName: { $in: followersCorrectos }
                      , { $sort: { felicitacionesPublicas: 1 }, $limit: 5 }

                      aFelicitar.forEach (u) ->
                        logger.info 'Felicitacion para '+u.screenName
                        usersStr += "@#{u.screenName} "
                        Followers.update u._id, { $inc: { felicitacionesPublicas: 1 } }

                      if usersStr
                        felicitacion = pregunta.felicitacion.replace '{users}', usersStr
                        felicitacion = HablemosQuechua.replaceVars felicitacion, palabra
                        logger.info 'Twitteando felicitacion'
                        twitter.post 'statuses/update', { status: felicitacion }, (err2, response2) ->
                          if err2
                            logger.error err2
                          else if response
                            logger.info response2
              , (e) ->
                logger.error 'Exception on bindEnvironment'
                logger.error e
              )
          else
            logger.error 'No access credentials found for user '+t.userId
