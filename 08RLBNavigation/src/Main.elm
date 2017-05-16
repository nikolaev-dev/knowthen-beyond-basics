port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Navigation
import LeaderBoard
import Runner
import Login


-- model


type alias Model =
    { page : Page
    , leaderBoard : LeaderBoard.Model
    , runner : Runner.Model
    , login : Login.Model
    , token : Maybe String
    , loggedIn : Bool
    }


type Page
    = NotFound
    | LeaderBoardPage
    | RunnerPage
    | LoginPage


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
    let
        page =
            hashToPage location.hash

        ( leaderboardInitModel, leaderboardCmd ) =
            LeaderBoard.init

        ( runnerInitModel, runnerCmd ) =
            Runner.init

        ( loginInitModel, loginCmd ) =
            Login.init

        initModel =
            { page = page
            , leaderBoard = leaderboardInitModel
            , runner = runnerInitModel
            , login = loginInitModel
            , token = flags.token
            , loggedIn = flags.token /= Nothing
            }

        cmds =
            Cmd.batch
                [ Cmd.map LeaderBoardMsg leaderboardCmd
                , Cmd.map LoginMsg loginCmd
                , Cmd.map RunnerMsg runnerCmd
                ]
    in
        ( initModel, cmds )



-- update


type Msg
    = Navigate Page
    | ChangePage Page
    | LeaderBoardMsg LeaderBoard.Msg
    | RunnerMsg Runner.Msg
    | LoginMsg Login.Msg
    | Logout


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Navigate page ->
            ( { model | page = page }, Navigation.newUrl <| pageToHash page )

        ChangePage page ->
            ( { model | page = page }, Cmd.none )

        LeaderBoardMsg msg ->
            let
                ( leaderBoardModel, cmd ) =
                    LeaderBoard.update msg model.leaderBoard
            in
                ( { model | leaderBoard = leaderBoardModel }
                , Cmd.map LeaderBoardMsg cmd
                )

        RunnerMsg msg ->
            let
                ( runnerModel, cmd ) =
                    Runner.update msg model.runner
            in
                ( { model | runner = runnerModel }
                , Cmd.map RunnerMsg cmd
                )

        Logout ->
            ( { model
                | loggedIn = False
                , token = Nothing
              }
            , deleteToken ()
            )

        LoginMsg msg ->
            let
                ( loginModel, cmd, token ) =
                    Login.update msg model.login

                loggenIn =
                    token /= Nothing

                saveTokenCmd =
                    case token of
                        Just jwt ->
                            saveToken jwt

                        Nothing ->
                            Cmd.none
            in
                ( { model
                    | login = loginModel
                    , token = token
                    , loggedIn = loggenIn
                  }
                , Cmd.batch
                    [ Cmd.map LoginMsg cmd
                    , saveTokenCmd
                    ]
                )



-- view


view : Model -> Html Msg
view model =
    let
        page =
            case model.page of
                LeaderBoardPage ->
                    Html.map LeaderBoardMsg
                        (LeaderBoard.view model.leaderBoard)

                RunnerPage ->
                    Html.map RunnerMsg
                        (Runner.view model.runner)

                LoginPage ->
                    Html.map LoginMsg
                        (Login.view model.login)

                NotFound ->
                    div [ class "main" ]
                        [ h1 []
                            [ text "Page Not Found!" ]
                        ]
    in
        div []
            [ pageHeader model
            , page
            ]


authHeaderView : Model -> Html Msg
authHeaderView model =
    if model.loggedIn then
        a [ onClick Logout ] [ text "Logout" ]
    else
        a [ onClick (Navigate LoginPage) ] [ text "Login" ]


pageHeader : Model -> Html Msg
pageHeader model =
    header []
        [ a [ onClick (Navigate LeaderBoardPage) ] [ text "Race Result" ]
        , ul []
            [ li []
                [ a [ onClick (Navigate RunnerPage) ] [ text "Add Runner" ]
                ]
            ]
        , ul []
            [ li [] [ authHeaderView model ] ]
        ]



-- subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        leaderBoardSub =
            LeaderBoard.subscriptions model.leaderBoard
    in
        Sub.batch
            [ Sub.map LeaderBoardMsg leaderBoardSub ]


hashToPage : String -> Page
hashToPage hash =
    case hash of
        "#/" ->
            LeaderBoardPage

        "" ->
            LeaderBoardPage

        "#/runner" ->
            RunnerPage

        "#/login" ->
            LoginPage

        _ ->
            NotFound


pageToHash : Page -> String
pageToHash page =
    case page of
        LeaderBoardPage ->
            "#/"

        RunnerPage ->
            "#/runner"

        LoginPage ->
            "#/login"

        NotFound ->
            "#notfound"


locationToMsg : Navigation.Location -> Msg
locationToMsg location =
    location.hash
        |> hashToPage
        |> ChangePage


type alias Flags =
    { token : Maybe String
    }


main : Program Flags Model Msg
main =
    Navigation.programWithFlags locationToMsg
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


port saveToken : String -> Cmd msg


port deleteToken : () -> Cmd msg
