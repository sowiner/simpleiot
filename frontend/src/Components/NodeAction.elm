module Components.NodeAction exposing (view)

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
import UI.ViewIf exposing (viewIf)


view : NodeOptions msg -> Element msg
view o =
    let
        icon =
            if o.node.typ == Node.typeAction then
                Icon.trendingUp

            else
                Icon.trendingDown

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
            [ icon
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

                        numberInput =
                            NodeInputs.nodeNumberInput opts ""

                        actionType =
                            Point.getText o.node.points Point.typeAction ""

                        actionSetValue =
                            actionType == Point.valueSetValue

                        actionPlayAudio =
                            actionType == Point.valuePlayAudio

                        valueType =
                            Point.getText o.node.points Point.typeValueType ""

                        nodeId =
                            Point.getText o.node.points Point.typeNodeID ""
                    in
                    [ textInput Point.typeDescription "Description" ""
                    , optionInput Point.typeAction
                        "Action"
                        [ ( Point.valueNotify, "notify" )
                        , ( Point.valueSetValue, "set node value" )
                        , ( Point.valuePlayAudio, "play audio" )
                        ]
                    , viewIf actionSetValue <|
                        optionInput Point.typePointType
                            "Point Type"
                            [ ( Point.typeValue, "value" )
                            , ( Point.typeValueSet, "set value (use for remote devices)" )
                            ]
                    , viewIf actionSetValue <| textInput Point.typeNodeID "Node ID" ""
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
                                        row
                                            [ spacing 10 ]
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
                    , viewIf actionSetValue <|
                        optionInput Point.typeValueType
                            "Point Value Type"
                            [ ( Point.valueNumber, "number" )
                            , ( Point.valueOnOff, "on/off" )
                            , ( Point.valueText, "text" )
                            ]
                    , viewIf actionSetValue <|
                        case valueType of
                            "number" ->
                                numberInput Point.typeValue "Value"

                            "onOff" ->
                                let
                                    onOffInput =
                                        NodeInputs.nodeOnOffInput opts ""
                                in
                                onOffInput Point.typeValue Point.typeValue "Value"

                            "text" ->
                                textInput Point.typeValueText "Value" ""

                            _ ->
                                Element.none
                    , viewIf actionPlayAudio <|
                        textInput Point.typeDevice "Device" ""
                    , viewIf actionPlayAudio <|
                        numberInput Point.typeChannel "Channel"
                    , viewIf actionPlayAudio <|
                        textInput Point.typeFilePath "Wav file path" "/absolute/path/to/sound.wav"
                    ]

                else
                    []
               )
