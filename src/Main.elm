module Main exposing (main)

import Browser
import Browser.Events exposing (onAnimationFrame)
import Html exposing (Html, button, div, p, text)
import Html.Events exposing (onClick)
import Task
import Time



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { stoppedTime : Int
    , time : Int
    , lastStartedAtMaybe : Maybe Int
    , totalTime : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { stoppedTime = 0, time = 0, lastStartedAtMaybe = Nothing, totalTime = 0 }, Cmd.none )


type Msg
    = Tick Time.Posix
    | Start
    | Stop
    | Reset
    | PlusN Int
    | SetLastStartedAt Time.Posix
    | SetStoppedTime Int Time.Posix



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        calcTime now lastStartedAt =
            model.stoppedTime + Time.posixToMillis now - lastStartedAt

        isStop =
            case model.lastStartedAtMaybe of
                Just _ ->
                    False

                Nothing ->
                    True
    in
    case msg of
        Tick now ->
            ( { model
                | time =
                    case model.lastStartedAtMaybe of
                        Just lastStartedAt ->
                            calcTime now lastStartedAt

                        Nothing ->
                            model.stoppedTime
              }
            , Cmd.none
            )

        Start ->
            if model.totalTime /= 0 then
                ( model, Task.perform SetLastStartedAt Time.now )

            else
                ( model, Cmd.none )

        Stop ->
            case model.lastStartedAtMaybe of
                Just lastStartedAt ->
                    ( model, Task.perform (SetStoppedTime lastStartedAt) Time.now )

                Nothing ->
                    ( model, Cmd.none )

        Reset ->
            if isStop then
                ( { model | stoppedTime = 0, time = 0 }, Cmd.none )

            else
                ( model, Cmd.none )

        PlusN n ->
            if isStop then
                ( { model | totalTime = model.totalTime + (n * 60 * 1000) }, Cmd.none )

            else
                ( model, Cmd.none )

        SetStoppedTime lastStartedAt now ->
            ( { model
                | stoppedTime =
                    calcTime now lastStartedAt
                , lastStartedAtMaybe = Nothing
              }
            , Cmd.none
            )

        SetLastStartedAt now ->
            ( { model | lastStartedAtMaybe = Just <| Time.posixToMillis now }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        restTotalTime =
            model.totalTime - model.time
    in
    div []
        [ p [ onClick <| PlusN -1 ] [ text "-" ]
        , p [] [ text <| (String.padLeft 2 '0' <| String.fromInt <| restTotalTime // (60 * 1000)) ++ ":" ++ (String.padLeft 2 '0' <| String.fromInt <| modBy (60 * 1000) restTotalTime // 1000) ]
        , p [ onClick <| PlusN 1 ] [ text "+" ]
        , button [ onClick Start ]
            [ text "start"
            ]
        , button [ onClick Stop ]
            [ text "stop"
            ]
        , button [ onClick <| PlusN 2 ]
            [ text "+2"
            ]
        , button [ onClick <| PlusN 5 ]
            [ text "+5"
            ]
        , button [ onClick <| PlusN 10 ]
            [ text "+10"
            ]
        , button [ onClick <| PlusN 30 ]
            [ text "+30"
            ]
        , p [ onClick Reset ] [ text "Reset" ]
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    onAnimationFrame Tick
