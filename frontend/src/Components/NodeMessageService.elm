module Components.NodeMessageService exposing (view)

import Api.Point as Point
import Components.NodeOptions exposing (NodeOptions, oToInputO)
import Element exposing (..)
import Element.Border as Border
import UI.Icon as Icon
import UI.NodeInputs as NodeInputs
import UI.Style exposing (colors)


view : NodeOptions msg -> Element msg
view o =
    column
        [ width fill
        , Border.widthEach { top = 2, bottom = 0, left = 0, right = 0 }
        , Border.color colors.black
        , spacing 6
        ]
    <|
        wrappedRow [ spacing 10 ]
            [ Icon.send
            , text <|
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
                    in
                    [ textInput Point.typeDescription "Description" ""
                    , optionInput Point.typeService
                        "Service"
                        [ ( Point.valueTwilio, "Twilio SMS" )
                        ]
                    , textInput Point.typeSID "SID" ""
                    , textInput Point.typeAuthToken "Auth Token" ""
                    , textInput Point.typeFrom "From" ""
                    ]

                else
                    []
               )
