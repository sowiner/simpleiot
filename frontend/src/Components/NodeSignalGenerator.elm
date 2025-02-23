module Components.NodeSignalGenerator exposing (view)

import Api.Point as Point
import Components.NodeOptions exposing (NodeOptions, oToInputO)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
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

        valueText =
            String.fromFloat (Round.roundNum 2 value)

        disabled =
            Point.getBool o.node.points Point.typeDisable ""

        summaryBackground =
            if disabled then
                Style.colors.ltgray

            else
                Style.colors.none
    in
    column
        [ width fill
        , Border.widthEach { top = 2, bottom = 0, left = 0, right = 0 }
        , Border.color Style.colors.black
        , spacing 6
        ]
    <|
        wrappedRow [ spacing 10, Background.color summaryBackground ]
            [ Icon.activity
            , text <|
                Point.getText o.node.points Point.typeDescription ""
            , el [ paddingXY 7 0 ] <|
                text <|
                    valueText
                        ++ " "
                        ++ Point.getText o.node.points Point.typeUnits ""
            , viewIf disabled <| text "(disabled)"
            ]
            :: (if o.expDetail then
                    let
                        labelWidth =
                            150

                        opts =
                            oToInputO o labelWidth

                        textInput =
                            NodeInputs.nodeTextInput opts ""

                        numberInput =
                            NodeInputs.nodeNumberInput opts ""

                        checkboxInput =
                            NodeInputs.nodeCheckboxInput opts ""
                    in
                    [ textInput Point.typeDescription "Description" ""
                    , numberInput Point.typeFrequency "Frequency (Hz)"
                    , numberInput Point.typeAmplitude "Amplitude (peak)"
                    , numberInput Point.typeOffset "Offset"
                    , numberInput Point.typeSampleRate "SampleRate (Hz)"
                    , textInput Point.typeUnits "Units" ""
                    , checkboxInput Point.typeHighRate "High rate data"
                    , numberInput Point.typeBatchPeriod "Batch (ms)"
                    , checkboxInput Point.typeDisable "Disable"
                    ]

                else
                    []
               )
