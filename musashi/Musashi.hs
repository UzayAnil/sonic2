module Musashi where

import           Control.Monad    (when)
import           Data.Bits        (rotate, shift, shiftR, (.&.), (.|.))
import           Data.IORef       (IORef, newIORef, readIORef, writeIORef)
import           Data.Word        (Word16, Word32, Word8)
import           Foreign.C.Types  (CInt (..), CUInt (..))
import           Foreign.Ptr      (Ptr, nullPtr)
import           Foreign.Storable (Storable, peekByteOff, pokeByteOff)
import           System.IO.Unsafe (unsafePerformIO)

-- Global state, could be done via C instead
musashiRom :: IORef (Ptr a)
{-# NOINLINE musashiRom #-}
musashiRom =
  unsafePerformIO (newIORef nullPtr)

musashiPeekRom :: Storable a => Int -> IO a
musashiPeekRom n = do
  r <- readIORef musashiRom
  peekByteOff r n

musashiPokeRom :: Storable a => Int -> a -> IO ()
musashiPokeRom n x = do
  r <- readIORef musashiRom
  pokeByteOff r n x

musashiSetRom :: Ptr a -> IO ()
musashiSetRom =
  writeIORef musashiRom

musashiInit :: IO ()
musashiInit = do
  m68k_init
  m68k_set_cpu_type m68k_CPU_TYPE_68000
  m68k_write_memory_32 0x0 0x4e720000

musashiSetSubroutine :: Word32 -> IO ()
musashiSetSubroutine address = do
  m68k_write_memory_32 0x4 address
  m68k_pulse_reset

musashiRun :: IO ()
musashiRun = do
  m68k_execute 1
  c <- m68k_cycles_remaining
  when (c /= 0) musashiRun

foreign import ccall m68k_init :: IO ()

foreign import ccall m68k_pulse_reset :: IO ()

foreign import ccall m68k_set_reg :: CUInt -> CUInt -> IO ()

foreign import ccall m68k_get_reg :: Ptr a -> CUInt -> IO CUInt

foreign import ccall m68k_set_cpu_type :: CUInt -> IO ()

foreign import ccall m68k_execute :: CUInt -> IO CInt

foreign import ccall m68k_cycles_remaining :: IO CInt

foreign export ccall m68k_read_memory_8 :: Int -> IO Word8

m68k_read_memory_8 :: Int -> IO Word8
m68k_read_memory_8 =
  musashiPeekRom

foreign export ccall m68k_write_memory_8 :: Int -> Word8 -> IO ()

m68k_write_memory_8 :: Int -> Word8 -> IO ()
m68k_write_memory_8 =
  musashiPokeRom

foreign export ccall m68k_read_memory_16 :: Int -> IO Word16

m68k_read_memory_16 :: Int -> IO Word16
m68k_read_memory_16 n =
  flip rotate 8 <$> musashiPeekRom n

foreign export ccall m68k_write_memory_16 :: Int -> Word16 -> IO ()

m68k_write_memory_16 :: Int -> Word16 -> IO ()
m68k_write_memory_16 n x =
  musashiPokeRom n (rotate x 8)

foreign export ccall m68k_read_memory_32 :: Int -> IO Word32

reverse_bytes_32 :: Word32 -> Word32
reverse_bytes_32 x =
  shift (x .&. 0x000000FF) 24
  .|. shift (x .&. 0x0000FF00) 8
  .|. shiftR (x .&. 0x00FF0000) 8
  .|. shiftR (x .&. 0xFF000000) 24

m68k_read_memory_32 :: Int -> IO Word32
m68k_read_memory_32 n =
  reverse_bytes_32 <$> musashiPeekRom n

foreign export ccall m68k_write_memory_32 :: Int -> Word32 -> IO ()

m68k_write_memory_32 :: Int -> Word32 -> IO ()
m68k_write_memory_32 n =
  musashiPokeRom n . reverse_bytes_32

m68k_CPU_TYPE_68000 :: CUInt
m68k_CPU_TYPE_68000 =
  1

m68k_REG_D0 :: CUInt
m68k_REG_D0 =
  0

m68k_REG_D1 :: CUInt
m68k_REG_D1 =
  1
