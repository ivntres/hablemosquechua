currSchedule = -> Schedules.findOne Session.get( 'scheduleId' )

Template.scheduleEdit.rendered = ->
  Tokenfield.init()
  TagsInput.init @

  $( @findAll 'select.chosen:not([data-combobox])[multiple]' )
    .each (i,s) ->
      $(s).chosen
        search_contains: true
        width: $(s).data('width')

  if sched = currSchedule()
    # Deps.autorun ->
    cols =  ['_id','diasDeLaSemana','horas','minutos']
    entradas = []
    EntradasSchedule.find( scheduleId: Session.get 'scheduleId' ).forEach (e) ->
      _(['scheduleId', 'userId', 'createdAt']).each (f) ->
        delete e[f]
      entradas.push e

    if not entradas or _(entradas).isEmpty()
      obj = {}
      _(cols).each (c) -> obj[c] = ''
      entradas = [obj]

    colWidths = _(cols).collect (v) -> 180
    colWidths[0] = 100

    diaRegExp = "([1-7])"
    diasValidator = new RegExp "^#{diaRegExp}(\\s*,\\s*#{diaRegExp})*$"

    horasRegExp = "([01]?[0-9]|2[0-3])"
    horasValidator = new RegExp "^#{horasRegExp}(\\s*,\\s*#{horasRegExp})*$"

    minsRegExp = "([0-5]?[0-9])"
    minsValidator = new RegExp "^#{minsRegExp}(\\s*,\\s*#{minsRegExp})*$"

    $("#entradas-table").handsontable
      columnSorting: true
      data: entradas
      colHeaders: ['_id','dias semana','horas','minutos']
      columns: [
        {data: '_id'}
        {data: 'diasDeLaSemana', validator: diasValidator, allowInvalid: true}
        {data: 'horas', validator: horasValidator, allowInvalid: true}
        {data: 'minutos', validator: minsValidator, allowInvalid: true}
      ]
      minSpareRows: 1
      colWidths: colWidths
      manualColumnResize: true
      outsideClickDeselects: false
      removeRowPlugin: true
      beforeRemoveRow: (index, amount) ->
        entrada = $('#entradas-table').handsontable 'getDataAtRow', index
        if entrada._id
          EntradasSchedule.remove entrada._id

Template.scheduleEdit.helpers
  currSchedule: -> currSchedule()
  conjuntosFrases: -> ConjuntosFrases.find()
  conjuntosPreguntas: -> ConjuntosPreguntas.find()

Template.scheduleEdit.events
  'submit #editScheduleForm': (e) ->
    e.preventDefault()
    sched = $(e.currentTarget).formToJSON()

    unless currSchedule()
      Schedules.insert sched, (err, result) ->
        unless err
          Router.go 'scheduleEdit', _id: result
        else
          logger.error err
          logger.error Schedules.namedContext("default").invalidKeys()
    else
      Schedules.update Session.get( 'scheduleId' ), {$set: sched}, (err) ->
        if err
          logger.error err
          logger.error Schedules.namedContext("default").invalidKeys()
        else
          data = $( '#entradas-table' ).handsontable( 'getData' ).slice 0, -1
          if data
            _(data).each (e, i) ->
              _(['diasDeLaSemana', 'horas', 'minutos']).each (f) ->
                e[f] = Utils.parseNumberArray(e[f]) if _(e[f]).isString()
              
              if e._id
                id = e._id
                delete e._id
                EntradasSchedule.update id, {$set:e}, (err) ->
                  unless err
                    $( '#entradas-table' ).handsontable( 'setDataAtCell', i, 0, id )
                  else
                    logger.error err
                    logger.error EntradasSchedule.namedContext("default").invalidKeys()
              else
                delete e._id
                e.scheduleId = Session.get 'scheduleId'
                EntradasSchedule.insert e, (err, result) ->
                  unless err
                    $( '#entradas-table' ).handsontable( 'setDataAtCell', i, 0, result )
                  else
                    logger.error err
                    logger.error EntradasSchedule.namedContext("default").invalidKeys()
    
  'change #variables': (e, tmpl) ->
    logger.info e.currentTarget.value
