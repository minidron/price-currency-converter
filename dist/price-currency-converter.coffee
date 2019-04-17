do ($=jQuery, window, document) ->

  class Control
    ###
    Смена валюты прайс-листа
    ###
    @_events: false

    render: ->
      # виджет смены валют
      options = ''
      $.map ListCurrency.currencyObj, (val, key) =>
        if @price.defaultCurrency is key
          selected = 'selected'
        else
          selected = ''
        options += "<option value='#{key}' #{selected}>#{val.name}</option>"
      select = "<select data-currency-control>#{options}</select>"
      "<div class='price__control-wrapper'>#{select}</div>"

    changePrices: (newCurrency) ->
      # запускаем механизм смены валют во всех секциях
      $.each Price.prices, (index, element) ->
        element.changePrices newCurrency

    registerEvents: ->
      if not Control._events
        control = @
        $(document).on 'change', '[data-currency-control]', (event) ->
          newCurrency = @value
          Cookies.set 'currentCurrency', @value, {expires: 1/24}
          control.changePrices newCurrency
      Control._events = true

    constructor: (@price) ->
      @el = @render()
      $(@price.el).before @el
      @registerEvents()
      if typeof Cookies.get('currentCurrency') isnt 'undefined'
        currentCurrency = Cookies.get 'currentCurrency'
      else
        currentCurrency = 'RUB'
      @price.changePrices currentCurrency
      $('[data-currency-control]').val currentCurrency


  class Price
    ###
    Прайс-лист
    ###
    _currentCurrency: {}

    @prices: []

    numberWithCommas: (num) ->
      # 10000 -> 10 000
      num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ')

    strToPrice: (str) ->
      # пробуем найти в строке цены
      parseFloat(str.replace(/(\s|\,)/g, ''))

    convertPrice: (element) ->
      # конвертор цены из базовой валюты секции в выбранную
      mainCurrency = 'USA'

      baseCurrencyPrice = $(element).data 'currencyPrice'
      baseCurrency = $(element).data 'currencyCurrency'
      if baseCurrency is @_currentCurrency.currency
        baseCurrencyPrice
      else
        if baseCurrency is mainCurrency
          mainPrice = baseCurrencyPrice
        else
          currency = ListCurrency.currencyObj[baseCurrency]
          mainPrice = baseCurrencyPrice / currency.value
          if @_currentCurrency.currency is mainCurrency
            return Math.ceil mainPrice
        Math.ceil mainPrice * @_currentCurrency.value

    changePrices: (newCurrency) ->
      # обновление всех цен
      @_currentCurrency = $.extend(
        {currency: newCurrency}
        ListCurrency.currencyObj[newCurrency])

      $('[data-currency-price]', @el).each (index, element) =>
        newPrice = @numberWithCommas @convertPrice element
        $(element).text "#{newPrice}#{@_currentCurrency.symbol}"

    _isPrice: (str, match, offset) ->
      if str.length is match.length
        true
      else if offset is 0 and /\s/g.test str.substr offset+match.length, 1
        true
      else if offset isnt 0 and /\s/g.test str.substr offset-1, 1
        true
      else
        false

    findPrices: (textNode) ->
      # поиск цен в каждой текстовой ноде
      if textNode.nodeValue.replace /\s/g,''
        replaced = false
        str = textNode.nodeValue.replace /\&nbsp\;/g, ' '
        patternPrice = /\d+(?:\,\d{3})*(?:[^\S\n]\d{3})*(?:\.\d{2})?/g
        results = str.replace patternPrice, (match, offset, s) =>
          price = @strToPrice match
          if @_isPrice(s, match, offset) and
              not isNaN(price) and
              price >= @minPrice
            replaced = true
            formatedPrice = @numberWithCommas price
            """
            <span data-currency-currency="#{@defaultCurrency}"
                  data-currency-price="#{price}">\
              #{formatedPrice}\
            </span>
            """
          else
            match

        if replaced
          tempNode = document.createElement 'div'
          tempNode.innerHTML = results
          while tempNode.firstChild
            textNode.parentNode.insertBefore tempNode.firstChild, textNode
          textNode.parentNode.removeChild textNode

    walkDOM: (el) ->
      # обход всех нод элемента
      if el.childNodes.length > 0
        for child in el.childNodes
          @walkDOM child
      else
        if el.nodeType is Node.TEXT_NODE
          if not el.parentNode.getAttribute('data-currency-price') and
              el.parentNode.getAttribute('data-currency-skip')
            @findPrices el

    initControl: ->
      # запуск контроллера для всех цен
      new Control @

    constructor: (@el) ->
      @constructor.prices.push @
      @defaultCurrency = $(@el).data 'currency'
      @minPrice = 32
      if $(@el).data 'currencyMin'
        @minPrice = $(@el).data 'currencyMin'
      @walkDOM @el
      @initControl()


  class ListCurrency
    ###
    Список валют
    ###
    @currencyObj: {}

    @_serialize: (obj) ->
      # json -> строка (для хранения в куках)
      JSON.stringify obj

    @_deserialize: (str) ->
      # строка -> json
      JSON.parse str

    @initPrice: ->
      # для каждой секции с ценами создаём отдельный объект Price
      $('[data-currency]').each (index, element) ->
        new Price element

    @fetchCurrency: ->
      # запрашиваем список валют
      $.ajax
        url: ListCurrency.url
        success: (data, status, jqXHR) ->
          result = {}
          $.map data, (val, key) ->
            result[val.code] =
              name: val.name
              symbol: val.symbol
              value: parseFloat val.value
          ListCurrency.currencyObj = result
          ListCurrency.initPrice()
          Cookies.set(
            'listCurrency'
            ListCurrency._serialize result
            {expires: 1/24}
          )
        error: (jqXHR, status) ->
          console.log status

    @getCurrency: ->
      # получаем курсы валют
      if typeof Cookies.get('listCurrency') isnt 'undefined'
        ListCurrency.currencyObj = ListCurrency._deserialize(
          Cookies.get('listCurrency')
        )
        ListCurrency.initPrice()
      else
        ListCurrency.fetchCurrency()

    constructor: (url) ->
      @constructor.url = url
      ListCurrency.getCurrency()

  window.PriceCurrencyConverter = ListCurrency
