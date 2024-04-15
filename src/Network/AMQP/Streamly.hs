{-# LANGUAGE FlexibleContexts #-}

module Network.AMQP.Streamly
  ( -- * How to use this library
    -- $use
    SendInstructions (..),
    produce,
    consume,
  )
where

import Control.Concurrent.MVar
import Control.Monad.IO.Class
  ( MonadIO,
    liftIO,
  )
import Data.Text (Text)
import Network.AMQP
import Streamly.Data.Stream
import qualified Streamly.Data.Stream as S
import Streamly.Data.Stream.Prelude
import qualified Streamly.Data.Stream.Prelude as S

-- | Informations to be sent
--
-- See @Network.AMQP.publishMsg'@ for options
data SendInstructions = SendInstructions {exchange :: Text, routingKey :: Text, mandatory :: Bool, message :: Message} deriving (Show)

-- | The Queue name
type Queue = Text

-- | Publish the produced messages
produce ::
  (MonadAsync m) =>
  Channel ->
  Stream m SendInstructions ->
  Stream m ()
produce channel = S.mapM send
  where
    send i = liftIO $ do
      publishMsg' channel (exchange i) (routingKey i) (mandatory i) (message i)
      return ()

-- | Stream messages from a queue
--
-- See @Network.AMQP.consumeMsgs@ for options
consume ::
  (MonadAsync m) =>
  Channel ->
  Queue ->
  Ack ->
  Stream m (Message, Envelope)
consume channel queue ack = S.concatEffect $ liftIO $ do
  mvar <- newEmptyMVar
  consumeMsgs channel queue Ack $ putMVar mvar
  return $ S.repeatM $ taking mvar
  where
    taking :: (MonadIO m) => MVar (Message, Envelope) -> m (Message, Envelope)
    taking mvar =
      liftIO $
        if ack == NoAck
          then do
            retrieved <- takeMVar mvar
            ackEnv $ snd retrieved
            return retrieved
          else takeMVar mvar

-- $use
--
-- This section contains basic step-by-step usage of the library.
--
-- You can either build a producer, which will publish all the messages of
-- a stream:
--
-- > Streamly.drain $ produce channel sendInstructionsStream
--
-- Or a consumer, which will contain the @Message@s and @Envelope@s of
-- a queue:
--
-- > Streamly.drain $ consume channel aQueue NoAck
