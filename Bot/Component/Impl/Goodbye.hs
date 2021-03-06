module Bot.Component.Impl.Goodbye (
    sayGoodbye
)   where

import Bot.Component
import Bot.IO

-- | Respond to PING messages from the IRC server.
sayGoodbye :: Bot Component
sayGoodbye = mkComponent $ \message ->
    case words message of
        _:"QUIT":_          ->  ircReply goodbyeMessage
        _:"PART":channel:_  ->  ircReplyTo channel goodbyeMessage
        _                   ->  return ()
    where
        goodbyeMessage = "And now his watch is ended."

