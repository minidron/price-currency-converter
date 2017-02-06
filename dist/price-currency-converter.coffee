do ($=jQuery, window, document) ->

  class Control
    ###
    Смена валюты прайс-листа
    ###
    @_events: false

    @currency:
      RUB:
        name: 'Российский рубль'
        symbol: '₽'
      AZN:
        name: 'Азербайджанский манат'
        symbol: '₼'
      GEL:
        name: 'Грузинский лари'
        symbol: '₾'
      USD:
        name: 'Доллар США'
        symbol: '$'
      CZK:
        name: 'Чешская крона'
        symbol: 'Kč'

    render: ->
      options = ''
      $.map Control.currency, (val, key) =>
        if @price.defaultCurrency is key
          selected = 'selected'
        else
          selected = ''
        options += "<option value='#{key}' #{selected}>#{val.name}</option>"
      select = "<select data-currency-control>#{options}</select>"
      "<div class='price__control-wrapper'>#{select}</div>"

    changePrices: (newCurrency) ->
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
      num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ')

    strToPrice: (str) ->
      parseFloat(str.replace(/(\s|\,)/g, ''))

    convertPrice: (element) ->
      defaultPrice = $(element).data('currencyPrice')
      defaultCurrency = $(element).data('currencyCurrency')
      if defaultCurrency is @_currentCurrency.currency
        defaultPrice
      else
        if defaultCurrency is 'RUB'
          rubPrice = defaultPrice
        else
          currency = ListCurrency.currencyObj[defaultCurrency]
          rubPrice = defaultPrice * currency.v
          if @_currentCurrency.currency is 'RUB'
            return Math.ceil rubPrice
        Math.ceil rubPrice / @_currentCurrency.v

    changePrices: (newCurrency) ->
      @_currentCurrency = $.extend(
        {currency: newCurrency}
        ListCurrency.currencyObj[newCurrency]
        Control.currency[newCurrency])

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
      if el.childNodes.length > 0
        for child in el.childNodes
          @walkDOM child
      else
        if el.nodeType is Node.TEXT_NODE
          if not el.parentNode.getAttribute('data-currency-price')
            @findPrices el

    initControl: ->
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
      JSON.stringify obj

    @_deserialize: (str) ->
      JSON.parse str

    @initPrice: ->
      $('[data-currency]').each (index, element) ->
        new Price element

    @fetchCurrency: ->
      $.ajax
        url: ListCurrency.url
        success: (data, status, jqXHR) ->
          console.log status
          result = {}
          $.map data, (val, key) ->
            result[key] =
              v: val.value
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
