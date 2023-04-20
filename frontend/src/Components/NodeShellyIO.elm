module Components.NodeShellyIO exposing (view)

import Api.Point as Point exposing (Point)
import Components.NodeOptions exposing (NodeOptions, oToInputO)
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import FormatNumber exposing (format)
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Round
import Time
import UI.Icon as Icon
import UI.NodeInputs as NodeInputs
import UI.Style as Style
import UI.ViewIf exposing (viewIf)
import Utils.Iso8601 as Iso8601


onOffDevices : List String
onOffDevices =
    [ "BulbDuo", "1pm", "rgbw2", "PlugUS" ]


isSettableOnOff : String -> Bool
isSettableOnOff typ =
    List.any (\a -> a == typ) onOffDevices


view : NodeOptions msg -> Element msg
view o =
    let
        disabled =
            Point.getBool o.node.points Point.typeDisable ""

        typ =
            Point.getText o.node.points Point.typeType ""

        desc =
            Point.getText o.node.points Point.typeDescription ""

        summary =
            "(" ++ typ ++ ")  " ++ desc

        valueElement =
            case
                typ
            of
                "PlusI4" ->
                    i4ValueSummary o.node.points

                _ ->
                    defaultSummary o.node.points
    in
    column
        [ width fill
        , Border.widthEach { top = 2, bottom = 0, left = 0, right = 0 }
        , Border.color Style.colors.black
        , spacing 6
        ]
    <|
        wrappedRow [ spacing 10 ]
            [ Icon.io
            , text summary
            , valueElement
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

                        checkboxInput =
                            NodeInputs.nodeCheckboxInput opts ""

                        onOffInput =
                            NodeInputs.nodeOnOffInput opts ""

                        deviceID =
                            Point.getText o.node.points Point.typeDeviceID ""

                        ip =
                            Point.getText o.node.points Point.typeIP ""

                        latestPointTime =
                            case Point.getLatest o.node.points of
                                Just point ->
                                    point.time

                                Nothing ->
                                    Time.millisToPosix 0
                    in
                    [ textDisplay "ID" deviceID
                    , textLinkDisplay "IP" ip ("http://" ++ ip)
                    , textInput Point.typeDescription "Description" ""
                    , viewIf (isSettableOnOff typ) <| onOffInput Point.typeValue Point.typeValueSet "Value"
                    , checkboxInput Point.typeDisable "Disable"
                    , text ("Last update: " ++ Iso8601.toDateTimeString o.zone latestPointTime)
                    , viewPoints o.zone <| Point.filterSpecialPoints <| List.sortWith Point.sort o.node.points
                    ]

                else
                    []
               )


defaultSummary : List Point -> Element msg
defaultSummary points =
    case Point.get points Point.typeValue "" of
        Just p ->
            displayOnOff p

        Nothing ->
            el [] <| text "off"


i4ValueSummary : List Point -> Element msg
i4ValueSummary points =
    let
        valuePoints =
            List.filter (\p -> p.typ == Point.typeValue) points |> List.sortBy .key

        valueElements =
            List.foldl
                (\p ret ->
                    List.append ret [ displayOnOff p ]
                )
                []
                valuePoints
    in
    row [ spacing 8 ] valueElements


displayOnOff : Point -> Element msg
displayOnOff p =
    let
        v =
            if p.value == 0 then
                "off"

            else
                "on"

        vBackgroundColor =
            if v == "on" then
                Style.colors.blue

            else
                Style.colors.none

        vTextColor =
            if v == "on" then
                Style.colors.white

            else
                Style.colors.black
    in
    el [ paddingXY 7 0, Background.color vBackgroundColor, Font.color vTextColor ] <|
        text <|
            v


textDisplay : String -> String -> Element msg
textDisplay label value =
    el [ paddingEach { top = 0, right = 0, bottom = 0, left = 70 } ] <|
        text <|
            label
                ++ ": "
                ++ value


textLinkDisplay : String -> String -> String -> Element msg
textLinkDisplay label value uri =
    el [ paddingEach { top = 0, right = 0, bottom = 0, left = 70 } ] <|
        row []
            [ text <|
                label
                    ++ ": "
            , newTabLink [ Font.underline ] { url = uri, label = text value }
            ]


viewPoints : Time.Zone -> List Point.Point -> Element msg
viewPoints z pts =
    if List.length pts <= 0 then
        Element.none

    else
        let
            formaters =
                metricFormaters z

            fm =
                formatMetric formaters
        in
        table [ padding 7 ]
            { data = List.map fm pts
            , columns =
                let
                    cell =
                        el [ paddingXY 15 5, Border.width 1 ]
                in
                [ { header = cell <| el [ Font.bold, centerX ] <| text "Point"
                  , width = fill
                  , view = \m -> cell <| text m.desc
                  }
                , { header = cell <| el [ Font.bold, centerX ] <| text "Value"
                  , width = fill
                  , view = \m -> cell <| el [ alignRight ] <| text m.value
                  }
                ]
            }


formatMetric : Dict String MetricFormat -> Point.Point -> { desc : String, value : String }
formatMetric formaters p =
    case Dict.get p.typ formaters of
        Just f ->
            { desc = f.desc p, value = f.vf p }

        Nothing ->
            Point.renderPoint2 p


type alias MetricFormat =
    { desc : Point.Point -> String
    , vf : Point.Point -> String
    }


metricFormaters : Time.Zone -> Dict String MetricFormat
metricFormaters _ =
    Dict.fromList
        [ ( "voltage", { desc = descS "Voltage", vf = \p -> Round.round 1 p.value } )
        , ( "temp", { desc = descS "Temperature (C)", vf = \p -> Round.round 1 p.value } )
        , ( "power", { desc = descS "Power", vf = \p -> Round.round 2 p.value } )
        , ( "current", { desc = descS "Current", vf = \p -> Round.round 2 p.value } )
        , ( "brightness", { desc = descS "Brightness", vf = toWhole } )
        , ( "lightTemp", { desc = descS "Light Temperature", vf = toWhole } )
        , ( "transition", { desc = descS "Transition", vf = toWhole } )
        , ( "white", { desc = descS "White", vf = toWhole } )
        ]


descS : String -> Point.Point -> String
descS d _ =
    d


toWhole : Point.Point -> String
toWhole p =
    format { usLocale | decimals = Exact 0 } p.value
