port module Main exposing (main)

import Browser
import Browser.Events exposing (onAnimationFrame)
import Browser.Navigation as Nav
import Html exposing (button, div, i, p, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Json.Decode as JD
import Json.Encode as JE
import Task
import Time
import Url
import Url.Parser as Parser


port createShareTimer : JE.Value -> Cmd msg


port saveShareTimer : JE.Value -> Cmd msg


port accessShareTimer : String -> Cmd msg


port getShareTimerId : (String -> msg) -> Sub msg


port getShareTimer : (JE.Value -> msg) -> Sub msg


port notifyTimeUp : () -> Cmd msg



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , shareTimerIdMaybe : Maybe String
    , stoppedTime : Int
    , time : Int
    , lastStartedAtMaybe : Maybe Int
    , totalTime : Int
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        urlParser =
            Parser.fragment identity

        shareTimerIdMaybe =
            Maybe.andThen identity <| Parser.parse urlParser url
    in
    ( { url = url
      , key = key
      , shareTimerIdMaybe = shareTimerIdMaybe
      , stoppedTime = 0
      , time = 0
      , lastStartedAtMaybe = Nothing
      , totalTime = 5000
      }
    , case shareTimerIdMaybe of
        Just shareTimerId ->
            accessShareTimer shareTimerId

        Nothing ->
            Cmd.none
    )


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | Tick Time.Posix
    | CreateShareTimer
    | GotShareTimerId String
    | GotShareTimer JE.Value
    | Start
    | Stop
    | Reset
    | PlusN Int
    | ResetTime
    | SetLastStartedAt Time.Posix
    | SetStoppedTime Int Time.Posix



-- UPDATE


jsonEncodeMaybeInt : Maybe Int -> JE.Value
jsonEncodeMaybeInt maybeInt =
    case maybeInt of
        Just int ->
            JE.int int

        Nothing ->
            JE.null


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

        createdShareTimerJsonValue =
            JE.object
                [ ( "totalTime", JE.int model.totalTime )
                , ( "lastStartedAtMaybe", jsonEncodeMaybeInt model.lastStartedAtMaybe )
                , ( "stoppedTime", JE.int model.stoppedTime )
                , ( "time", JE.int model.time )
                ]

        savedShareTimerJsonValue newModel shareTimerId =
            JE.object
                [ ( "totalTime", JE.int newModel.totalTime )
                , ( "lastStartedAtMaybe", jsonEncodeMaybeInt newModel.lastStartedAtMaybe )
                , ( "stoppedTime", JE.int newModel.stoppedTime )
                , ( "time", JE.int newModel.time )
                , ( "shareTimerId", JE.string shareTimerId )
                ]
    in
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }, Cmd.none )

        Tick now ->
            let
                time =
                    case model.lastStartedAtMaybe of
                        Just lastStartedAt ->
                            calcTime now lastStartedAt

                        Nothing ->
                            model.stoppedTime
            in
            if time >= model.totalTime then
                ( { model
                    | time = model.totalTime
                    , lastStartedAtMaybe = Nothing
                    , stoppedTime = model.totalTime
                  }
                , if model.lastStartedAtMaybe /= Nothing then
                    notifyTimeUp ()

                  else
                    Cmd.none
                )

            else
                ( { model | time = time }, Cmd.none )

        CreateShareTimer ->
            ( model
            , createShareTimer createdShareTimerJsonValue
            )

        GotShareTimerId shareTimerId ->
            ( { model | shareTimerIdMaybe = Just shareTimerId }
            , Cmd.batch [ Nav.replaceUrl model.key <| "#" ++ shareTimerId, accessShareTimer shareTimerId ]
            )

        GotShareTimer json ->
            case JD.decodeValue shareTimerDecoder json of
                Ok { totalTime, lastStartedAtMaybe, stoppedTime, time } ->
                    ( { model
                        | totalTime = totalTime
                        , lastStartedAtMaybe = lastStartedAtMaybe
                        , stoppedTime = stoppedTime
                        , time = time
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        Start ->
            if model.totalTime /= 0 then
                ( model, Cmd.batch [ Task.perform SetLastStartedAt Time.now ] )

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
                let
                    newModel =
                        { model | stoppedTime = 0, time = 0 }
                in
                ( newModel
                , Maybe.withDefault Cmd.none <|
                    Maybe.map
                        (\shareTimerId ->
                            saveShareTimer <| savedShareTimerJsonValue newModel shareTimerId
                        )
                        model.shareTimerIdMaybe
                )

            else
                ( model, Cmd.none )

        PlusN n ->
            if isStop then
                ( { model | totalTime = model.totalTime + (n * 60 * 1000) }, Cmd.none )

            else
                ( model, Cmd.none )

        ResetTime ->
            if isStop then
                ( { model | totalTime = 0 }, Cmd.none )

            else
                ( model, Cmd.none )

        SetStoppedTime lastStartedAt now ->
            let
                newModel =
                    { model
                        | stoppedTime =
                            calcTime now lastStartedAt
                        , lastStartedAtMaybe = Nothing
                    }
            in
            ( newModel
            , Maybe.withDefault Cmd.none <|
                Maybe.map
                    (\shareTimerId ->
                        saveShareTimer <| savedShareTimerJsonValue newModel shareTimerId
                    )
                    model.shareTimerIdMaybe
            )

        SetLastStartedAt now ->
            let
                newModel =
                    { model | lastStartedAtMaybe = Just <| Time.posixToMillis now }
            in
            ( newModel
            , Maybe.withDefault Cmd.none <|
                Maybe.map
                    (\shareTimerId ->
                        saveShareTimer <| savedShareTimerJsonValue newModel shareTimerId
                    )
                    model.shareTimerIdMaybe
            )


type alias ShareTimer =
    { totalTime : Int
    , lastStartedAtMaybe : Maybe Int
    , stoppedTime : Int
    , time : Int
    }


shareTimerDecoder : JD.Decoder ShareTimer
shareTimerDecoder =
    JD.map4 ShareTimer
        (JD.field "totalTime" JD.int)
        (JD.field "lastStartedAtMaybe" <| JD.maybe JD.int)
        (JD.field "stoppedTime" <| JD.int)
        (JD.field "time" <| JD.int)



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        restTotalTime =
            model.totalTime - model.time
    in
    { title = "share timer"
    , body =
        [ div [ class "ly_cont" ]
            [ div [ class "bl_timer" ]
                [ p [ onClick <| PlusN -1, class "el_button" ] [ text "-" ]
                , p [] [ text <| (String.padLeft 2 '0' <| String.fromInt <| restTotalTime // (60 * 1000)) ++ ":" ++ (String.padLeft 2 '0' <| String.fromInt <| modBy (60 * 1000) restTotalTime // 1000) ]
                , p [ onClick <| PlusN 1, class "el_button" ] [ text "+" ]
                , i [ class "fas fa-share-square el_share_button", onClick CreateShareTimer ] []
                ]
            , div
                [ class "bl_buttons" ]
                [ button [ onClick Start ]
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
                , button [ onClick ResetTime ]
                    [ text "0"
                    ]
                ]
            , p [ onClick Reset, class "el_reset" ] [ text "Reset" ]
            ]
        ]
    }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ onAnimationFrame Tick
        , getShareTimerId GotShareTimerId
        , getShareTimer GotShareTimer
        ]
