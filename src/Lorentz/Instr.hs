module Lorentz.Instr
  ( ( # )
  , (:->) (..)
  , compileLorentz
  , type (&)
  , Lambda
  , Contract
  , Coercible_
  , coerce_
  , nop
  , drop
  , dup
  , swap
  , push
  , some
  , none
  , unit
  , ifNone
  , pair
  , car
  , cdr
  , left
  , right
  , ifLeft
  , nil
  , cons
  , size
  , emptySet
  , emptyMap
  , map
  , iter
  , mem
  , get
  , update
  , if_
  , ifCons
  , loop
  , loopLeft
  , lambda
  , exec
  , dip
  , failWith
  , cast
  , pack
  , unpack
  , concat
  , concat'
  , slice, isNat, add, sub, rsub, mul, ediv, abs
  , neg
  , lsl
  , lsr
  , or
  , and
  , xor
  , not
  , compare
  , eq0
  , neq0
  , lt0
  , gt0
  , le0
  , ge0
  , int
  , self
  , contract
  , transferTokens
  , setDelegate
  , createAccount
  , createContract
  , implicitAccount
  , now
  , amount
  , balance
  , checkSignature
  , sha256
  , sha512
  , blake2B
  , hashKey
  , stepsToQuota
  , source
  , sender
  , address
  ) where

import Prelude hiding
  (EQ, GT, LT, abs, and, compare, concat, drop, get, map, not, or, some, swap, xor)

import qualified Data.Kind as Kind

import Lorentz.Arith
import Lorentz.Constraints
import Lorentz.Polymorphic
import Lorentz.Value
import Michelson.Typed ((:+>), Instr(..), Notes(NStar), T(..), ToT, ToTs, Value'(..), forbiddenOp)
import Michelson.Typed.Arith
import Michelson.Typed.Polymorphic ()

newtype (inp :: [Kind.Type]) :-> (out :: [Kind.Type]) =
  I { unI :: ToTs inp :+> ToTs out }
infixr 1 :->

-- | For use outside of Lorentz.
compileLorentz :: (inp :-> out) -> (ToTs inp :+> ToTs out)
compileLorentz = unI

type (&) (a :: Kind.Type) (b :: [Kind.Type]) = a ': b
infixr 2 &

-- TODO: this is the second operator with this name
-- call it differently?
(#) :: (a :-> b) -> (b :-> c) -> a :-> c
I l # I r = I (l `Seq` r)

type Lambda i o = '[i] :-> '[o]

instance IsoValue (Lambda inp out) where
  type ToT (Lambda inp out) = 'TLambda (ToT inp) (ToT out)
  toVal = VLam . unI
  fromVal (VLam l) = I l

-- | Whether two types have the same Michelson representation.
type Coercible_ a b = ToT a ~ ToT b

-- | Convert between values of types that have the same representation.
coerce_ :: Coercible_ a b => a & s :-> b & s
coerce_ = I Nop

type Contract cp st = '[(cp, st)] :-> '[([Operation], st)]

-- TODO: move everything till this point to some Lorentz.Base?

nop :: s :-> s
nop = I Nop

drop :: a & s :-> s
drop = I DROP

dup  :: a & s :-> a & a & s
dup = I DUP

swap :: a & b & s :-> b & a & s
swap = I SWAP

push :: forall t s .(KnownValue t, NoOperation t, IsoValue t) => t -> (s :-> t & s)
push a = I $ forbiddenOp @(ToT t) $ PUSH (toVal a)

some :: a & s :-> Maybe a & s
some = I SOME

none :: forall a s . KnownValue a => s :-> (Maybe a & s)
none = I NONE

unit :: s :-> () & s
unit = I UNIT

ifNone
  :: (s :-> s') -> (a & s :-> s') -> (Maybe a & s :-> s')
ifNone (I l) (I r) = I (IF_NONE l r)

pair :: a & b & s :-> (a, b) & s
pair = I PAIR

car :: (a, b) & s :-> a & s
car = I CAR

cdr :: (a, b) & s :-> b & s
cdr = I CDR

left :: forall a b s. KnownValue b => a & s :-> Either a b & s
left = I LEFT

right :: forall a b s. KnownValue a => b & s :-> Either a b & s
right = I RIGHT

ifLeft
  :: (a & s :-> s') -> (b & s :-> s') -> (Either a b & s :-> s')
ifLeft (I l) (I r) = I (IF_LEFT l r)

nil :: KnownValue p => s :-> List p & s
nil = I NIL

cons :: a & List a & s :-> List a & s
cons = I CONS

ifCons
  :: (a & List a & s :-> s') -> (s :-> s') -> (List a & s :-> s')
ifCons (I l) (I r) = I (IF_CONS l r)

size :: SizeOpHs c => c & s :-> Natural & s
size = I SIZE

emptySet :: (KnownCValue e) => s :-> Set e & s
emptySet = I EMPTY_SET

emptyMap :: (KnownCValue k, KnownValue v)
         => s :-> Map k v & s
emptyMap = I EMPTY_MAP

map
  :: (MapOpHs c, IsoMapOpRes c b)
  => (MapOpInpHs c & s :-> b & s) -> (c & s :-> MapOpResHs c b & s)
map (I action) = I (MAP action)

iter
  :: (IterOpHs c)
  => (IterOpElHs c & s :-> s) -> (c & s :-> s)
iter (I action) = I (ITER action)

mem :: MemOpHs c => MemOpKeyHs c & c & s :-> Bool & s
mem = I MEM

get :: GetOpHs c => GetOpKeyHs c & c & s :-> Maybe (GetOpValHs c) & s
get = I GET

update :: UpdOpHs c => UpdOpKeyHs c & UpdOpParamsHs c & c & s :-> c & s
update = I UPDATE

if_ :: (s :-> s') -> (s :-> s') -> (Bool & s :-> s')
if_ (I l) (I r) = I (IF l r)

loop :: (s :-> Bool & s) -> (Bool & s :-> s)
loop (I b) = I (LOOP b)

loopLeft
  :: (a & s :-> Either a b & s) -> (Either a b & s :-> b & s)
loopLeft (I b) = I (LOOP_LEFT b)

lambda
  :: (KnownValue i, KnownValue o)
  => Lambda i o -> (s :-> Lambda i o & s)
lambda (I l) = I (LAMBDA $ VLam l)

exec :: a & Lambda a b & s :-> b & s
exec = I EXEC

dip :: (s :-> s') -> (a & s :-> a & s')
dip (I a) = I (DIP a)

failWith :: (KnownValue a) => a & s :-> t
failWith = I FAILWITH

cast :: KnownValue a => (a & s :-> a & s)
cast = I CAST

pack :: forall a s. (KnownValue a, NoOperation a) => a & s :-> ByteString & s
pack = I $ forbiddenOp @(ToT a) PACK

unpack :: forall a s. (KnownValue a, NoOperation a) => ByteString & s :-> Maybe a & s
unpack = I $ forbiddenOp @(ToT a) UNPACK

concat :: ConcatOpHs c => c & c & s :-> c & s
concat = I CONCAT

concat' :: ConcatOpHs c => List c & s :-> c & s
concat' = I CONCAT'

slice :: SliceOpHs c => Natural & Natural & c & s :-> Maybe c & s
slice = I SLICE

isNat :: Integer & s :-> Maybe Natural & s
isNat = I ISNAT

add
  :: ArithOpHs Add n m
  => n & m & s :-> ArithResHs Add n m & s
add = I ADD

sub
  :: ArithOpHs Sub n m
  => n & m & s :-> ArithResHs Sub n m & s
sub = I SUB

rsub
  :: ArithOpHs Sub n m
  => m & n & s :-> ArithResHs Sub n m & s
rsub = swap # sub

mul
  :: ArithOpHs Mul n m
  => n & m & s :-> ArithResHs Mul n m & s
mul = I MUL

ediv :: EDivOpHs n m
     => n & m & s
     :-> Maybe ((EDivOpResHs n m, EModOpResHs n m)) & s
ediv = I EDIV

abs :: UnaryArithOpHs Abs n => n & s :-> UnaryArithResHs Abs n & s
abs = I ABS

neg :: UnaryArithOpHs Neg n => n & s :-> UnaryArithResHs Neg n & s
neg = I NEG


lsl
  :: ArithOpHs Lsl n m
  => n & m & s :-> ArithResHs Lsl n m & s
lsl = I LSL

lsr
  :: ArithOpHs Lsr n m
  => n & m & s :-> ArithResHs Lsr n m & s
lsr = I LSR

or
  :: ArithOpHs Or n m
  => n & m & s :-> ArithResHs Or n m & s
or = I OR

and
  :: ArithOpHs And n m
  => n & m & s :-> ArithResHs And n m & s
and = I AND

xor
  :: (ArithOpHs Xor n m)
  => n & m & s :-> ArithResHs Xor n m & s
xor = I XOR

not :: UnaryArithOpHs Not n => n & s :-> UnaryArithResHs Not n & s
not = I NOT

compare :: ArithOpHs Compare n m
        => n & m & s :-> ArithResHs Compare n m & s
compare = I COMPARE

eq0 :: UnaryArithOpHs Eq' n => n & s :-> UnaryArithResHs Eq' n & s
eq0 = I EQ

neq0 :: UnaryArithOpHs Neq n => n & s :-> UnaryArithResHs Neq n & s
neq0 = I NEQ

lt0 :: UnaryArithOpHs Lt n => n & s :-> UnaryArithResHs Lt n & s
lt0 = I LT

gt0 :: UnaryArithOpHs Gt n => n & s :-> UnaryArithResHs Gt n & s
gt0 = I GT

le0 :: UnaryArithOpHs Le n => n & s :-> UnaryArithResHs Le n & s
le0 = I LE

ge0 :: UnaryArithOpHs Ge n => n & s :-> UnaryArithResHs Ge n & s
ge0 = I GE

int :: Natural & s :-> Integer & s
int = I INT

self :: forall cp s . s :-> ContractAddr cp & s
self = I SELF

contract :: (KnownValue p) => Address & s :-> Maybe (ContractAddr p) & s
contract = I (CONTRACT NStar)

transferTokens
  :: forall p s. (KnownValue p, NoOperation p)
  => p & Mutez & ContractAddr p & s :-> Operation & s
transferTokens = I $ forbiddenOp @(ToT p) TRANSFER_TOKENS

setDelegate :: Maybe KeyHash & s :-> Operation & s
setDelegate = I SET_DELEGATE

createAccount :: KeyHash & Maybe KeyHash & Bool & Mutez & s
              :-> Operation & Address & s
createAccount = I CREATE_ACCOUNT


createContract :: forall p g s.
                  (KnownValue p, NoOperation p, KnownValue g, NoOperation g)
               => '[(p, g)] :-> '[(List Operation, g)]
               -> KeyHash & Maybe KeyHash & Bool & Bool & Mutez & g & s
               :-> Operation & Address & s
createContract (I c) =
  I $ forbiddenOp @(ToT p) $ forbiddenOp @(ToT g) (CREATE_CONTRACT c)

implicitAccount :: KeyHash & s :-> ContractAddr () & s
implicitAccount = I IMPLICIT_ACCOUNT

now :: s :-> Timestamp & s
now = I NOW

amount :: s :-> Mutez & s
amount = I AMOUNT

balance :: s :-> Mutez & s
balance = I BALANCE

checkSignature :: PublicKey & Signature & ByteString & s :-> Bool & s
checkSignature = I CHECK_SIGNATURE

sha256 :: ByteString & s :-> ByteString & s
sha256 = I SHA256

sha512 :: ByteString & s :-> ByteString & s
sha512 = I SHA512

blake2B :: ByteString & s :-> ByteString & s
blake2B = I BLAKE2B

hashKey :: PublicKey & s :-> KeyHash & s
hashKey = I HASH_KEY

stepsToQuota :: s :-> Natural & s
stepsToQuota = I STEPS_TO_QUOTA

source :: s :-> Address & s
source = I SOURCE

sender :: s :-> Address & s
sender = I SENDER

address :: ContractAddr a & s :-> Address & s
address = I ADDRESS
