HablemosQuechua =
  Utils:
    weeksBetween: (d1, d2) ->
      aDay = 24 * 60 * 60 * 1000

      weeks = {}
      _([0..7]).each (wd) ->
        weeks[wd] = []

      d = undefined
      i = d1.getTime()
      n = d2.getTime()

      while i <= n
        date = new Date(i)
        d = date.getDay()
        # day zero remains empty: mon=1 ... sun=7
        if d is 0
          d = 7
        else
          d + 1

        weeks[d].push date
        i += aDay

      return weeks

    getHorarios: (rules) ->
      weeks = HablemosQuechua.Utils.weeksBetween rules.desde, rules.hasta
      horarios = []
      Schedules.find( { _id: { $in: rules.scheduleIds } } ).forEach (s) ->
        EntradasSchedule.find( scheduleId: s._id ).forEach (e) ->
          _(e.diasDeLaSemana).each (ddls) ->
            _(weeks[ddls]).each (dia) ->
              _(e.horas).each (hora) ->
                _(e.minutos).each (mins) ->
                  tweetTime = moment dia
                  tweetTime.hour hora
                  tweetTime.minutes mins
                  tweetTime = moment tweetTime.format( 'YYYY-MM-DD HH:mm:ss.SSS' )
                  tweetTime.seconds 0
                  tweetTime.milliseconds 0
                  if tweetTime.isAfter rules.desde and tweetTime.isBefore rules.hasta
                    horarios.push tweetTime.toDate()
      horarios

    getFrases: (scheduleIds) ->
      frases = []
      if conjuntoFrasesIds = Schedules.findOne( _id: { $in: scheduleIds } ).conjuntoFrasesIds
        ConjuntosFrases.find( _id: { $in: conjuntoFrasesIds } ).forEach (cf) ->
          frases = _.union frases, Frases.find(
            { conjuntoId: cf._id },
            { fields: { frase: 1, rafaga: 1 } }
          ).fetch()
      frases

    getPreguntas: (scheduleIds) ->
      preguntas = []
      if conjuntoPreguntasIds = Schedules.findOne( _id: { $in: scheduleIds } ).conjuntoPreguntasIds
        ConjuntosPreguntas.find( _id: { $in: conjuntoPreguntasIds } ).forEach (cf) ->
          preguntas = _.union preguntas, Preguntas.find(
            { conjuntoId: cf._id },
            { fields: { pregunta: 1, respuesta: 1, felicitacion: 1, respuestaIncorrecta: 1, delayRespuesta: 1 } }
          ).fetch()
      preguntas

    getPalabras: (scheduleIds) ->
      palabras = []
      if conjuntoFrasesIds = Schedules.findOne( _id: { $in: scheduleIds } ).conjuntoFrasesIds
        ConjuntosFrases.find( _id: { $in: conjuntoFrasesIds } ).forEach (cf) ->
          Diccionarios.find( _id: { $in: cf.diccionarioIds } ).forEach (d) ->
            palabras = _.union palabras, PalabrasDiccionario.find(
              { diccionarioId: d._id },
              { fields: { createdAt: 0, userId: 0, diccionarioId: 0 } }
            ).fetch()
      if conjuntoPreguntasIds = Schedules.findOne( _id: { $in: scheduleIds } ).conjuntoPreguntasIds
        ConjuntosPreguntas.find( _id: { $in: conjuntoPreguntasIds } ).forEach (cp) ->
          Diccionarios.find( _id: { $in: cp.diccionarioIds } ).forEach (d) ->
            palabras = _.union palabras, PalabrasDiccionario.find(
              { diccionarioId: d._id },
              { fields: { createdAt: 0, userId: 0, diccionarioId: 0 } }
            ).fetch()
      palabras

    getOne: (array) ->
      index = _.random array.length - 1
      array[index]

  replaceVars: (frase, palabra) ->
    vars = _(palabra).keys()
    _(vars).each (varName) ->
      frase = frase.replace '{'+varName+'}', palabra[varName]
    return frase


  newTweet: (palabra, frase, horario) ->
    tweet =
      palabraId: palabra._id
      fechaHora: horario
      status: Tweets.STATUS.PENDING

    tweet.esFrase = frase.frase?
    tweet.esPregunta = frase.pregunta?

    texto = if tweet.esFrase then frase.frase else frase.pregunta

    fraseStr = HablemosQuechua.replaceVars texto, palabra
    if fraseStr.length <= 140
      tweet.tweet = fraseStr
      if tweet.esFrase
        tweet.fraseId = frase._id
        if frase.rafaga and not _( _(frase.rafaga).without null, '' ).isEmpty()
          tweets = [tweet]
          lastTime = moment horario
          _( _(frase.rafaga).without null, '' ).each (r, i) ->
            horarioR = lastTime.clone()
            horarioR.add 'minutes', 3
            rafaga =
              fraseId: frase._id
              palabraId: palabra._id
              fechaHora: horarioR.toDate()
              status: Tweets.STATUS.PENDING
              rafagaIdx: i
              esFrase: true
              esRafaga: true
              esPregunta: false
            rafaga.tweet = HablemosQuechua.replaceVars r, palabra
            tweets.push rafaga
            lastTime = horarioR.clone()
          return tweets
        else
          return tweet
      else if tweet.esPregunta
        tweet.preguntaId = frase._id
        tweets = [tweet]
        horarioR = moment horario
        horarioR.add 'minutes', (frase.delayRespuesta or 3)
        respuesta =
          preguntaId: frase._id
          palabraId: palabra._id
          fechaHora: horarioR.toDate()
          status: Tweets.STATUS.PENDING
          esPregunta: true
          esRespuesta: true
          esFrase: false
        respuesta.tweet = HablemosQuechua.replaceVars frase.respuesta, palabra
        tweets.push respuesta
        return tweets


