module Components.NodeDevice exposing (view)

import Api.Node as Node
import Api.Point as Point exposing (Point)
import Components.NodeOptions exposing (NodeOptions)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Time
import UI.Icon as Icon
import UI.Style as Style exposing (colors)
import UI.ViewIf exposing (viewIf)
import Utils.Duration as Duration
import Utils.Iso8601 as Iso8601


view : NodeOptions msg -> Element msg
view o =
    let
        sysState =
            Point.getText o.node.points Point.typeSysState ""

        sysStateIcon =
            case sysState of
                -- not sure why I can't use defines in Node.elm here
                "powerOff" ->
                    Icon.power

                "offline" ->
                    Icon.cloudOff

                "online" ->
                    Icon.cloud

                _ ->
                    Element.none

        background =
            Style.colors.white
    in
    column
        [ width fill
        , Border.widthEach { top = 2, bottom = 0, left = 0, right = 0 }
        , Border.color colors.black
        , Background.color background
        , spacing 6
        ]
    <|
        wrappedRow
            [ spacing 10 ]
            [ Icon.device
            , sysStateIcon
            , Input.text
                [ Background.color background ]
                { onChange =
                    \d ->
                        o.onEditNodePoint
                            [ Point Point.typeDescription "" o.now 0 d 0 ]
                , text = Node.description o.node
                , placeholder = Just <| Input.placeholder [] <| text "node description"
                , label = Input.labelHidden "node description"
                }
            ]
            :: (if o.expDetail then
                    let
                        latestPointTime =
                            case Point.getLatest o.node.points of
                                Just point ->
                                    point.time

                                Nothing ->
                                    Time.millisToPosix 0

                        versionHW =
                            case Point.get o.node.points Point.typeVersionHW "" of
                                Just point ->
                                    "HW: " ++ point.text

                                Nothing ->
                                    ""

                        versionOS =
                            case Point.get o.node.points Point.typeVersionOS "" of
                                Just point ->
                                    "OS: " ++ point.text

                                Nothing ->
                                    ""

                        versionApp =
                            case Point.get o.node.points Point.typeVersionApp "" of
                                Just point ->
                                    "App: " ++ point.text

                                Nothing ->
                                    ""
                    in
                    [ viewPoints <| Point.filterSpecialPoints <| List.sortWith Point.sort o.node.points
                    , text ("Last update: " ++ Iso8601.toDateTimeString o.zone latestPointTime)
                    , text
                        ("Time since last update: "
                            ++ Duration.toString
                                (Time.posixToMillis o.now
                                    - Time.posixToMillis latestPointTime
                                )
                        )
                    , viewIf (versionHW /= "" || versionOS /= "" || versionApp /= "") <|
                        text
                            ("Version: "
                                ++ versionHW
                                ++ " "
                                ++ versionOS
                                ++ " "
                                ++ versionApp
                            )
                    ]

                else
                    []
               )


viewPoints : List Point.Point -> Element msg
viewPoints ios =
    column
        [ padding 16
        , spacing 6
        ]
    <|
        List.map (Point.renderPoint >> text) ios
