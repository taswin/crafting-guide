###
Crafting Guide - inventory_controller.coffee

Copyright (c) 2014-2015 by Redwood Labs
All rights reserved.
###

BaseController  = require './base_controller'
{Duration}      = require '../constants'
{Event}         = require '../constants'
{Key}           = require '../constants'
ImageLoader     = require './image_loader'
NameFinder      = require '../models/name_finder'
StackController = require './stack_controller'

########################################################################################################################

module.exports = class InventoryController extends BaseController

    @MAX_QUANTITY = 9999

    @ONLY_DIGITS = /^[0-9]*$/

    constructor: (options={})->
        if not options.imageLoader? then throw new Error 'options.imageLoader is required'
        if not options.model? then throw new Error 'options.model is required'
        if not options.modPack? then throw new Error 'options.modPack is required'

        @editable    = options.editable    ?= true
        @icon        = options.icon        ?= '/images/chest_front.png'
        @imageLoader = options.imageLoader
        @modPack     = options.modPack
        @nameFinder  = options.nameFinder  ?= new NameFinder options.modPack
        @onChange    = options.onChange    ?= -> # do nothing
        @title       = options.title       ?= 'Inventory'

        options.templateName  = 'inventory'
        super options

        @_stackControllers = []

        @listenTo @modPack, Event.change, => @refresh()

    # Event Methods ################################################################################

    onAddButtonClicked: ->
        if @$nameField.val().trim().length is 0
            @$nameField.focus()
            return

        item = @modPack.findItemByName @$nameField.val()
        return unless item?

        @model.add item.slug, 1
        @$nameField.val ''

        @$scrollbox.scrollTop @$scrollbox.prop 'scrollHeight'
        @$nameField.autocomplete 'close'

        @onChange()

    onClearButtonClicked: ->
        @model.clear()
        @onChange()

    onItemSelected: ->
        func = =>
            @onNameFieldChanged()
            @onAddButtonClicked()
            @$nameField.blur()

        setTimeout func, 10 # needed to allow the autocomplete to finish
        return true

    onNameFieldBlur: ->
        item = @modPack.findItemByName @$nameField.val()
        @$nameField.val if item? then item.name else ''
        @onNameFieldChanged()

    onNameFieldChanged: ->
        @_refreshButtonState()

    onNameFieldFocused: ->
        @$nameField.val ''
        @$nameField.autocomplete 'search'

    onNameFieldKeyUp: (event)->
        if event.which is Key.Return
            @onAddButtonClicked()

    # BaseController Overrides #####################################################################

    onDidRender: ->
        @$addButton     = @$('button[name="add"]')
        @$clearButton   = @$('button[name="clear"]')
        @$icon          = @$('.icon')
        @$editPanel     = @$('.edit')
        @$nameField     = @$('input[name="name"]')
        @$scrollbox     = @$('.scrollbox')
        @$table         = @$('table')
        @$toolbar       = @$('.toolbar')
        @$title         = @$('h2 p')
        super

    refresh: ->
        @$editPanel.css display:(if @editable then 'table-row' else 'none')
        @$toolbar.css display:(if @editable then 'block' else 'none')
        @$scrollbox.css bottom:(if @editable then @$toolbar.height() else '0')

        @$icon.attr 'src', @icon
        @$title.html @title

        @_refreshStacks()
        @_refreshNameAutocomplete()
        @_refreshButtonState()

        super

    # Backbone.View Overrides ######################################################################

    events: ->
        return _.extend super,
            'blur input[name="name"]':      'onNameFieldBlur'
            'click button[name="add"]':     'onAddButtonClicked'
            'click button[name="clear"]':   'onClearButtonClicked'
            'focus input[name="name"]':     'onNameFieldFocused'
            'input input[name="name"]':     'onNameFieldChanged'
            'keyup input[name="name"]':     'onNameFieldKeyUp'

    # Private Methods ##############################################################################

    _refreshButtonState: ->
        if @model.isEmpty then @$clearButton.attr('disabled', 'disabled') else @$clearButton.removeAttr('disabled')

        noText        = @$nameField.val().trim().length is 0
        itemValid     = @modPack.findItemByName(@$nameField.val())?
        disable       = not (itemValid or noText)
        if disable then @$addButton.attr('disabled', 'disabled') else @$addButton.removeAttr('disabled')

    _refreshNameAutocomplete: ->
        onChanged = => @onNameFieldChanged()
        onSelected = => @onItemSelected()

        @$nameField.autocomplete
            source:    (request, callback)=> callback @nameFinder.search request.term
            delay:     0
            minLength: 0
            change:    onChanged
            close:     onChanged
            select:    onSelected

    _refreshStacks: ->
        @_stackControllers ?= []
        index = 0

        $lastRow = @$table.find 'tr:last-child'
        @model.each (stack)=>
            controller = @_stackControllers[index]
            if not controller?
                controller = new StackController
                    editable:    @editable
                    imageLoader: @imageLoader
                    model:       stack
                    modPack:     @modPack
                    onChange:    @onChange
                    onRemove:    if not @editable then null else (stack)=> @_removeStack(stack)
                controller.render()
                controller.$el.hide()
                controller.$el.insertBefore $lastRow
                controller.$el.slideDown duration:Duration.fast
                @_stackControllers.push controller
            else
                controller.model = stack
            index += 1

        while @_stackControllers.length > index
            controller = @_stackControllers.pop()
            controller.$el.fadeOut duration:Duration.fast, complete:-> @remove()

    _removeStack: (stack)->
        @model.remove stack.itemSlug, stack.quantity
