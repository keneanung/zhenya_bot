{-# OPTIONS_GHC -fno-cse #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE RecordWildCards #-}
import Bot
import Bot.Component.Command
import Bot.IO

import Data.List
import System.Console.CmdArgs.Implicit

-- | A data type defining the various command line arguments that may be
-- supplied.
data Flags = Flags {
        serverFlag  ::  String
    ,   portFlag    ::  Int
    ,   nickFlag    ::  String
    ,   channelFlag ::  [String]
} deriving (Data, Typeable, Show)

-- | Declare the default values, help strings and options values for each of the
-- different flags.
flagDefinition = Flags {
        serverFlag  =   "crafting.dangerbear.in"
                    &=  help "The IRC server to connect to"
                    &=  opt "server"
                    &=  typ "HostName"
    ,   portFlag    =   6667
                    &=  help "The port on which the IRC server is running"
                    &=  opt "port"
                    &=  typ "PortNumber"
    ,   nickFlag    =   "zhenya_bot"
                    &=  help "The nick that the bot should take"
                    &=  opt "nick"
                    &=  typ "Nick"
    ,   channelFlag =   []
                    &=  help "The channel that the bot should join"
                    &=  opt "channel"
                    &=  typ "Channel"
}   &=  summary "Greatest guys IRC bot"
    &=  program "bot"

-- | Grab configuration from the command line, attach appropriate BotComponents
-- and start the IRC bot.
main :: IO ()
main = do
    Flags{..} <-  cmdArgs flagDefinition
    runBot $ defaultBotConfig {
            cfgServer   = serverFlag
        ,   cfgPort     = portFlag
        ,   cfgChannel  = nub channelFlag
        ,   cfgNick     = nickFlag
        } `withComponents` [
        ]
