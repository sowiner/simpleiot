module Components.NodeCondition exposing (view)

import Api.Node as Node
import Api.Point as Point
import Components.NodeOptions exposing (CopyMove(..), NodeOptions, findNode, oToInputO)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import UI.Icon as Icon
import UI.NodeInputs as NodeInputs
import UI.Style as Style


view : NodeOptions msg -> Element msg
view o =
    let
        active =
            Point.getBool o.node.points Point.typeActive ""

        descBackgroundColor =
            if active then
                Style.colors.blue

            else
                Style.colors.none

        descTextColor =
            if active then
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
            [ Icon.check
            , el [ Background.color descBackgroundColor, Font.color descTextColor ] <|
                text <|
                    Point.getText o.node.points Point.typeDescription ""
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

                        conditionType =
                            Point.getText o.node.points Point.typeConditionType ""
                    in
                    [ textInput Point.typeDescription "Description" ""
                    , optionInput Point.typeConditionType
                        "Type"
                        [ ( Point.valuePointValue, "point value" )
                        , ( Point.valueSchedule, "schedule" )
                        ]
                    , case conditionType of
                        "pointValue" ->
                            pointValue o labelWidth

                        "schedule" ->
                            schedule o labelWidth

                        _ ->
                            text "Please select condition type"
                    ]

                else
                    []
               )


schedule : NodeOptions msg -> Int -> Element msg
schedule o labelWidth =
    let
        opts =
            oToInputO o labelWidth
    in
    NodeInputs.nodeTimeDateInput opts labelWidth


pointValue : NodeOptions msg -> Int -> Element msg
pointValue o labelWidth =
    let
        opts =
            oToInputO o labelWidth

        textInput =
            NodeInputs.nodeTextInput opts ""

        numberInput =
            NodeInputs.nodeNumberInput opts ""

        optionInput =
            NodeInputs.nodeOptionInput opts ""

        conditionValueType =
            Point.getText o.node.points Point.typeValueType ""

        nodeId =
            Point.getText o.node.points Point.typeNodeID ""
    in
    column
        [ width fill
        , spacing 6
        ]
        [ textInput Point.typeNodeID "Node ID" ""
        , if nodeId /= "" then
            let
                nodeDesc =
                    case findNode o.nodes nodeId of
                        Just node ->
                            el [ Background.color Style.colors.ltblue ] <|
                                text <|
                                    "("
                                        ++ Node.getBestDesc node
                                        ++ ")"

                        Nothing ->
                            el [ Background.color Style.colors.orange ] <| text "(node not found)"
            in
            el [ Font.italic, paddingEach { top = 0, right = 0, left = 170, bottom = 0 } ] <|
                nodeDesc

          else
            Element.none
        , case o.copy of
            CopyMoveNone ->
                Element.none

            Copy id _ desc ->
                if nodeId /= id then
                    let
                        label =
                            row [ spacing 10 ]
                                [ text <| "paste ID for node: "
                                , el
                                    [ Font.italic
                                    , Background.color Style.colors.ltblue
                                    ]
                                  <|
                                    text desc
                                ]
                    in
                    NodeInputs.nodePasteButton opts label Point.typeNodeID id

                else
                    Element.none
        , optionInput Point.typePointType
            "Point Type"
            [ ( Point.typeValue, "value" )
            , ( Point.typeValueSet, "set value" )
            , ( Point.typeErrorCount, "error count" )
            , ( Point.typeSysState, "system state" )
            , ( Point.typeActive, "active" )
            ]
        , textInput Point.typePointKey "Point Key" ""
        , optionInput Point.typeValueType
            "Point Value Type"
            [ ( Point.valueNumber, "number" )
            , ( Point.valueOnOff, "on/off" )
            , ( Point.valueText, "text" )
            ]
        , if conditionValueType /= Point.valueOnOff then
            let
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
            optionInput Point.typeOperator "Operator" operators

          else
            Element.none
        , case conditionValueType of
            "number" ->
                numberInput Point.typeValue "Point Value"

            "onOff" ->
                let
                    onOffInput =
                        NodeInputs.nodeOnOffInput opts ""
                in
                onOffInput Point.typeValue Point.typeValue "Point Value"

            "text" ->
                textInput Point.typeValueText "Point Value" ""

            _ ->
                Element.none
        , numberInput Point.typeMinActive "Min active time (m)"
        ]
