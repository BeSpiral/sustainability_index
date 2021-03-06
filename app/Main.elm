module Main exposing (main)

import Browser
import Element exposing (..)
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes
import NetworkParser exposing (NodeUrl(..))
import Network
    exposing
        ( Network(..)
        , emptyNetwork
        )
import NetworkParser
import Network exposing (SimpleEdge)
import CSV
import Widget
import Svg exposing (svg)
import Display
import FlowModel
    exposing
        ( exampleNetwork
        , displayListWithTitle
        , displayNodes
        , displayEdges
        , report
        )


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type Msg
    = NoOp
    | InputNetworkString String
    | InputSourceNode String
    | InputTargetNode String
    | InputEdgeFlow String
    | InputAvatarString String
    | UpdateNetwork
    | ToggleDisplayMode


type alias Model =
    { message : String
    , networkAsString : String
    , network : Network
    , sourceNode : String
    , targetNode : String
    , edgeFlow : String
    , dataFormat : DataFormat
    , avatarList : List NodeUrl
    , avatarCSV : String
    , displayMode : DisplayMode
    }


type DataFormat
    = CSV
    | SingleLine


type DisplayMode
    = NetworkDisplay
    | AvatarDisplay


initialNetworkAsCSV =
    """Lucca, Pablo, 30
Lucca, Karla, 90.4
Pablo, Ranulfo, 22
Karla, Luz, 40
Karla, Maria, 55
Karla, Ranulfo, 31.4
Jim, Karla, 30
Jim, Ranulfo, 20
Pablo, Karla, 34
Ranulfo, Lucca, 20
Luz, Maria, 22
George, Maria, 31.4
Lucca, Jim, 30
"""


initialAvatarCSV =
    """AA, https://s3.amazonaws.com/noteimages/jxxcarlson/hello.jpg
BB, https://s3.amazonaws.com/noteimages/jxxcarlson/hello.jpg
"""


initialAvatarList =
    CSV.getAvatarList initialAvatarCSV


initialModel : Model
initialModel =
    { message = "Hello!"
    , networkAsString = initialNetworkAsCSV
    , network = CSV.networkFromString initialNetworkAsCSV
    , sourceNode = ""
    , targetNode = ""
    , edgeFlow = ""
    , dataFormat = CSV
    , avatarList = initialAvatarList
    , avatarCSV = initialAvatarCSV
    , displayMode = NetworkDisplay
    }


type alias Flags =
    {}


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initialModel, Cmd.none )


subscriptions model =
    Sub.batch
        []


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        InputNetworkString str ->
            ( { model | networkAsString = str }, Cmd.none )

        InputAvatarString str ->
            ( { model | avatarCSV = str }, Cmd.none )

        UpdateNetwork ->
            let
                newEdgeFlow =
                    String.toFloat model.edgeFlow |> Maybe.withDefault 0

                newNetworkAsString =
                    if model.sourceNode /= "" && model.targetNode /= "" && newEdgeFlow > 0 then
                        model.networkAsString
                            |> simpleEdgeListFromString model.dataFormat
                            |> Network.replaceSimpleEdge model.sourceNode model.targetNode newEdgeFlow
                            |> CSV.csvFromEdgeList
                    else if model.sourceNode /= "" && model.targetNode /= "" && newEdgeFlow == 0 then
                        model.networkAsString
                            |> simpleEdgeListFromString model.dataFormat
                            |> Network.deleteSimpleEdge model.sourceNode model.targetNode
                            |> CSV.csvFromEdgeList
                    else
                        model.networkAsString

                newNetwork =
                    CSV.networkFromString newNetworkAsString

                updateNetwork : NodeUrl -> Network -> Network
                updateNetwork (NodeUrl nodeName imageUrl) network_ =
                    Network.changeNodeInfoInNetwork nodeName imageUrl network_

                newAvatarList =
                    CSV.getAvatarList model.avatarCSV

                newNetwork2 =
                    List.foldl updateNetwork newNetwork newAvatarList
            in
                ( { model
                    | networkAsString = newNetworkAsString
                    , network = newNetwork2
                    , avatarList = newAvatarList
                  }
                , Cmd.none
                )

        InputSourceNode str ->
            ( { model | sourceNode = str }, Cmd.none )

        InputTargetNode str ->
            ( { model | targetNode = str }, Cmd.none )

        InputEdgeFlow str ->
            ( { model | edgeFlow = str }, Cmd.none )

        ToggleDisplayMode ->
            case model.displayMode of
                NetworkDisplay ->
                    ( { model | displayMode = AvatarDisplay }, Cmd.none )

                AvatarDisplay ->
                    ( { model | displayMode = NetworkDisplay }, Cmd.none )


simpleEdgeListFromString : DataFormat -> (String -> List SimpleEdge)
simpleEdgeListFromString dataFormat =
    case dataFormat of
        CSV ->
            CSV.simpleEdgeListFromString

        SingleLine ->
            NetworkParser.simpleEdgeListFromString


view : Model -> Html Msg
view model =
    layout [] (mainRow model)


mainRow : Model -> Element Msg
mainRow model =
    column [ width fill, height fill, centerX, centerY, spacing 20, Font.size 16 ]
        [ el [ Font.bold, Font.size 24, centerX, centerY, moveUp 20 ] (text "Network")
        , row [ centerX, spacing 20 ] (display model)
        , row [ centerX, paddingEach { left = 0, right = 0, top = 20, bottom = 8 } ] [ networkEntryForm model ]
        , row [ centerX, paddingEach { left = 0, right = 0, top = 0, bottom = 80 } ] [ toggleDisplayModeButton model ]
        ]


display : Model -> List (Element Msg)
display model =
    case model.displayMode of
        NetworkDisplay ->
            networkDisplay model

        AvatarDisplay ->
            avatarDisplay model


networkDisplay : Model -> List (Element Msg)
networkDisplay model =
    [ column [ centerX, alignTop, paddingEach { left = 0, right = 80, top = 0, bottom = 0 } ] [ displayNetwork model ]
    , column dataColumnStyle (displayListWithTitle "Nodes" <| displayNodes model.network)
    , column dataColumnStyle (displayListWithTitle "Edges" <| [ networkInput model ])
    , column [ centerX, alignTop, paddingEach { left = 40, right = 0, top = 0, bottom = 0 } ] [ report model.network ]
    ]


avatarDisplay : Model -> List (Element Msg)
avatarDisplay model =
    [ column [ centerX, alignTop, paddingEach { left = 0, right = 80, top = 0, bottom = 0 } ] [ displayNetwork model ]
    , column dataColumnStyle (displayListWithTitle "Avatars" <| [ avatarInput model ])
    ]


dataColumnStyle =
    [ centerX, spacing 10, alignTop, scrollbarX, height (px 300) ]


avatarInput : Model -> Element Msg
avatarInput model =
    Input.multiline [ width (px 300), height (px 400), spacing 12, moveUp 15 ]
        { onChange = InputAvatarString
        , text = model.avatarCSV
        , placeholder = Nothing
        , label = Input.labelAbove [ Font.size 0, Font.bold ] (text "avatarParser")
        , spellcheck = False
        }


networkInput : Model -> Element Msg
networkInput model =
    Input.multiline [ width (px 180), height (px 400), spacing 8, moveUp 15 ]
        { onChange = InputNetworkString
        , text = model.networkAsString
        , placeholder = Nothing
        , label = Input.labelAbove [ Font.size 0, Font.bold ] (text "Edges")
        , spellcheck = False
        }


toggleDisplayModeButton : Model -> Element Msg
toggleDisplayModeButton model =
    Input.button (Widget.buttonStyle ++ [ moveDown 7.5 ])
        { onPress = Just ToggleDisplayMode
        , label = Element.text <| toggleDisplayTitle model
        }


toggleDisplayTitle : Model -> String
toggleDisplayTitle model =
    case model.displayMode of
        AvatarDisplay ->
            "Display: Avatar List"

        NetworkDisplay ->
            "Display: Network"


updateNetworkButton : Model -> Element Msg
updateNetworkButton model =
    Input.button (Widget.buttonStyle ++ [ moveDown 7.5 ])
        { onPress = Just UpdateNetwork
        , label = Element.text "Update Network"
        }


displayNetwork : Model -> Element msg
displayNetwork model =
    Element.html
        (svg [ Html.Attributes.width 400, Html.Attributes.height 400 ]
            (Display.networkDisplay 200 model.network)
        )


networkEntryForm : Model -> Element Msg
networkEntryForm model =
    row [ spacing 8 ]
        [ inputSourceNode model, inputTargetNode model, inputEdgeFlow model, updateNetworkButton model ]


inputSourceNode model =
    Input.text [ height (px 25), width (px 100) ]
        { onChange = InputSourceNode
        , text = model.sourceNode
        , placeholder = Nothing
        , label = Input.labelAbove [ Font.size 14, Font.bold ] (text "Source node")
        }


inputTargetNode model =
    Input.text [ height (px 25), width (px 100) ]
        { onChange = InputTargetNode
        , text = model.targetNode
        , placeholder = Nothing
        , label = Input.labelAbove [ Font.size 14, Font.bold ] (text "Target node")
        }


inputEdgeFlow model =
    Input.text [ height (px 25), width (px 100) ]
        { onChange = InputEdgeFlow
        , text = model.edgeFlow
        , placeholder = Nothing
        , label = Input.labelAbove [ Font.size 14, Font.bold ] (text "Flow")
        }
