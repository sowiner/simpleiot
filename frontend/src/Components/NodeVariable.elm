module Components.NodeVariable exposing (view)

import Api.Point as Point
import Components.NodeOptions exposing (NodeOptions, oToInputO)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Round
import UI.Icon as Icon
import UI.NodeInputs as NodeInputs
import UI.Style as Style
import UI.ViewIf exposing (viewIf)


view : NodeOptions msg -> Element msg
view o =
    let
        value =
            Point.getValue o.node.points Point.typeValue ""

        variableType =
            Point.getText o.node.points Point.typeVariableType ""

        valueText =
            if variableType == Point.valueNumber then
                String.fromFloat (Round.roundNum 2 value)

            else if value == 0 then
                "off"

            else
                "on"

        valueBackgroundColor =
            if valueText == "on" then
                Style.colors.blue

            else
                Style.colors.none

        valueTextColor =
            if valueText == "on" then
                Style.colors.white

            else
                Style.colors.black
    in
    column
        [ width fill
        , Border.widthEach { top = 2, bottom = 0, left = 0, right = 0 }
        , Border.color Style.colors.black
        , spacing 6
        ]
    <|
        wrappedRow [ spacing 10 ]
            [ Icon.variable
            , text <|
                Point.getText o.node.points Point.typeDescription ""
            , el [ paddingXY 7 0, Background.color valueBackgroundColor, Font.color valueTextColor ] <|
                text <|
                    valueText
                        ++ (if variableType == Point.valueNumber then
                                " " ++ Point.getText o.node.points Point.typeUnits ""

                            else
                                ""
                           )
            ]
            :: (if o.expDetail then
                    let
                        labelWidth =
                            150

                        opts =
                            oToInputO o labelWidth

                        textInput =
                            NodeInputs.nodeTextInput opts ""

                        optionInput =
                            NodeInputs.nodeOptionInput opts ""

                        numberInput =
                            NodeInputs.nodeNumberInput opts ""

                        onOffInput =
                            NodeInputs.nodeOnOffInput opts ""
                    in
                    [ textInput Point.typeDescription "Description" ""
                    , optionInput Point.typeVariableType
                        "Variable type"
                        [ ( Point.valueOnOff, "On/Off" )
                        , ( Point.valueNumber, "Number" )
                        ]
                    , viewIf (variableType == Point.valueOnOff) <|
                        onOffInput
                            Point.typeValue
                            Point.typeValue
                            "Value"
                    , viewIf (variableType == Point.valueNumber) <|
                        numberInput Point.typeValue "Value"
                    , viewIf (variableType == Point.valueNumber) <|
                        textInput Point.typeUnits "Units" ""
                    ]

                else
                    []
               )
