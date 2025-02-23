module UI.Sanitize exposing (float, hmParser, parseHM, time)

import Parser exposing ((|.), Parser)


float : String -> String
float input =
    Tuple.second <| floatHelper ( input, "" )


floatHelper : ( String, String ) -> ( String, String )
floatHelper state =
    let
        sIn =
            Tuple.first state

        sInList =
            String.toList sIn
    in
    case sInList of
        c :: rest ->
            let
                sOut =
                    Tuple.second state
            in
            if Char.isDigit c || (c == '.' && not (String.contains "." sOut)) then
                let
                    sOutList =
                        String.toList sOut
                in
                floatHelper ( String.fromList rest, String.fromList <| sOutList ++ [ c ] )

            else
                state

        _ ->
            state



-- sanitizeTime looks for a valid time input in the form of hh:mm
-- this function simply stops when it hits an invalid
-- portion and returns the valid portion


time : String -> String
time t =
    Tuple.second <| timeHelper ( t, "" )


timeHelper : ( String, String ) -> ( String, String )
timeHelper state =
    let
        sIn =
            Tuple.first state

        sInList =
            String.toList sIn
    in
    case sInList of
        c :: rest ->
            let
                sOut =
                    Tuple.second state

                sOutList =
                    String.toList sOut

                checkDigit =
                    \ch chRest ->
                        if Char.isDigit ch then
                            timeHelper ( String.fromList chRest, String.fromList <| sOutList ++ [ ch ] )

                        else
                            ( "", sOut )
            in
            case List.length sOutList of
                0 ->
                    checkDigit c rest

                1 ->
                    if c == ':' then
                        -- add a leading digit and try again
                        timeHelper ( sIn, String.fromList <| '0' :: sOutList )

                    else if Char.isDigit c then
                        let
                            sOutNew =
                                String.fromList <| sOutList ++ [ c ]
                        in
                        case String.toInt (String.slice 0 2 sOutNew) of
                            Just hr ->
                                if hr > 23 then
                                    ( "", sOut )

                                else
                                    timeHelper ( String.fromList rest, sOutNew )

                            Nothing ->
                                ( "", sOut )

                    else
                        ( "", sOut )

                2 ->
                    if c == ':' then
                        timeHelper ( String.fromList rest, String.fromList <| sOutList ++ [ c ] )

                    else
                        ( "", sOut )

                3 ->
                    checkDigit c rest

                4 ->
                    if Char.isDigit c then
                        let
                            sOutNew =
                                String.fromList <| sOutList ++ [ c ]
                        in
                        case String.toInt (String.slice 3 5 sOutNew) of
                            Just hr ->
                                if hr > 59 then
                                    ( "", sOut )

                                else
                                    timeHelper ( String.fromList rest, sOutNew )

                            Nothing ->
                                ( "", sOut )

                    else
                        ( "", sOut )

                _ ->
                    ( "", sOut )

        _ ->
            -- we are done
            state


parseHM : String -> Maybe String
parseHM t =
    Parser.run hmParser t
        |> Result.toMaybe


hmParser : Parser String
hmParser =
    Parser.getChompedString <|
        Parser.succeed identity
            |. (Parser.oneOf [ Parser.backtrackable altIntParser, Parser.int ]
                    |> Parser.andThen
                        (\v ->
                            if v < 0 || v > 23 then
                                Parser.problem "hour is out of range"

                            else
                                Parser.succeed v
                        )
               )
            |. Parser.symbol ":"
            |. ((Parser.oneOf [ altIntParser, Parser.int ]
                    |> Parser.andThen
                        (\v ->
                            if v < 0 || v > 59 then
                                Parser.problem "minute is not in range"

                            else
                                Parser.succeed v
                        )
                )
                    |> Parser.getChompedString
                    |> Parser.andThen
                        (\s ->
                            if String.length s /= 2 then
                                Parser.problem "minute must be 2 digits"

                            else
                                Parser.succeed s
                        )
               )


altIntParser : Parser Int
altIntParser =
    Parser.symbol "0" |> Parser.andThen (\_ -> Parser.int)
