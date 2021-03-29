module Components.NodeCondition exposing (view)

import Api.Node exposing (Node)
import Api.Point as Point exposing (Point)
import Element exposing (..)
import Element.Border as Border
import Time
import UI.Form as Form
import UI.Icon as Icon
import UI.Style exposing (colors)
import UI.ViewIf exposing (viewIf)


view :
    { isRoot : Bool
    , now : Time.Posix
    , zone : Time.Zone
    , modified : Bool
    , expDetail : Bool
    , parent : Maybe Node
    , node : Node
    , onApiDelete : String -> msg
    , onEditNodePoint : String -> Point -> msg
    , onDiscardEdits : msg
    , onApiPostPoints : String -> msg
    }
    -> Element msg
view o =
    let
        labelWidth =
            150

        textInput =
            Form.nodeTextInput
                { onEditNodePoint = o.onEditNodePoint
                , node = o.node
                , now = o.now
                , labelWidth = labelWidth
                }

        numberInput =
            Form.nodeNumberInput
                { onEditNodePoint = o.onEditNodePoint
                , node = o.node
                , now = o.now
                , labelWidth = labelWidth
                }

        optionInput =
            Form.nodeOptionInput
                { onEditNodePoint = o.onEditNodePoint
                , node = o.node
                , now = o.now
                , labelWidth = labelWidth
                }

        onOffInput =
            Form.nodeOnOffInput
                { onEditNodePoint = o.onEditNodePoint
                , node = o.node
                , now = o.now
                , labelWidth = labelWidth
                }

        conditionValueType =
            Point.getText o.node.points Point.typeValueType

        operators =
            case conditionValueType of
                "number" ->
                    [ ( Point.valueGreaterThan, ">" )
                    , ( Point.valueLessThan, "<" )
                    , ( Point.valueEqual, "=" )
                    , ( Point.valueNotEqual, "!=" )
                    ]

                "text" ->
                    [ ( Point.valueEqual, "=" )
                    , ( Point.valueNotEqual, "!=" )
                    , ( Point.valueContains, "contains" )
                    ]

                _ ->
                    []
    in
    column
        [ width fill
        , Border.widthEach { top = 2, bottom = 0, left = 0, right = 0 }
        , Border.color colors.black
        , spacing 6
        ]
    <|
        wrappedRow [ spacing 10 ]
            [ Icon.check
            , text <|
                Point.getText o.node.points Point.typeDescription
            ]
            :: (if o.expDetail then
                    [ textInput Point.typeDescription "Description"
                    , textInput Point.typeID "Node ID"
                    , optionInput Point.typePointType
                        "Point Type"
                        [ ( Point.typeValue, "value" )
                        , ( Point.typeValueSet, "set value" )
                        , ( Point.typeErrorCount, "error count" )
                        , ( Point.typeSysState, "system state" )
                        ]
                    , textInput Point.typePointID "Point ID"
                    , numberInput Point.typePointIndex "Point Index"
                    , optionInput Point.typeValueType
                        "Point Value Type"
                        [ ( Point.valueNumber, "number" )
                        , ( Point.valueOnOff, "on/off" )
                        , ( Point.valueText, "text" )
                        ]
                    , if conditionValueType /= Point.valueOnOff then
                        optionInput Point.typeOperator "Operator" operators

                      else
                        Element.none
                    , case conditionValueType of
                        "number" ->
                            numberInput Point.typeValue "Point Value"

                        "onOff" ->
                            onOffInput Point.typeValue Point.typeValue "Point Value"

                        "text" ->
                            textInput Point.typeValue "Point Value"

                        _ ->
                            Element.none
                    , numberInput Point.typeMinActive "Min active time (m)"
                    , viewIf o.modified <|
                        Form.buttonRow
                            [ Form.button
                                { label = "save"
                                , color = colors.blue
                                , onPress = o.onApiPostPoints o.node.id
                                }
                            , Form.button
                                { label = "discard"
                                , color = colors.gray
                                , onPress = o.onDiscardEdits
                                }
                            ]
                    ]

                else
                    []
               )
