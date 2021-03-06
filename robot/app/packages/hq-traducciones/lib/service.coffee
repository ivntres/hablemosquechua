TraduccionesService =
  looksLikeOne: (userId, tweet) ->
    pregunta = null
    palabra = null
    traduccion = null

    ConjuntosTraducciones.find( {userId: userId} ).forEach (cp) ->
      variables = []
      Diccionarios.find( _id: { $in: cp.diccionarioIds } ).forEach (d) ->
        _(d.variables).each (v) ->
          variables.push v

      Traducciones.find( conjuntoId: cp._id ).forEach (t) ->
        localAux = t.pregunta.replace /".*"/i, ""
        externalAux = tweet.replace /".*"/i, ""

        localAux = new RegExp(localAux,'i')
        if externalAux.match localAux
          traduccion = t
          palabra =
            palabra: tweet.match( /"(.*)"/i, "" )[1]
            placeholder: t.pregunta.match( /"(.*)"/i, "" )[1].replace('{','').replace('}','').replace(/\\/g,'')
    
    if traduccion
      return {
        traduccion: traduccion
        palabra: palabra
      }
    else return false
