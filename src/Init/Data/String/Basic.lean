/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Leonardo de Moura
-/
prelude
import Init.Data.List.Basic
import Init.Data.Char.Basic
import Init.Data.Option.Basic
universe u

def List.asString (s : List Char) : String :=
  ⟨s⟩

namespace String

instance : OfNat String.Pos (nat_lit 0) where
  ofNat := {}

instance : LT String :=
  ⟨fun s₁ s₂ => s₁.data < s₂.data⟩

@[extern "lean_string_dec_lt"]
instance decLt (s₁ s₂ : @& String) : Decidable (s₁ < s₂) :=
  List.hasDecidableLt s₁.data s₂.data

/--
Returns the length of a string in Unicode code points.

Examples:
* `"".length = 0`
* `"abc".length = 3`
* `"L∃∀N".length = 4`
-/
@[extern "lean_string_length"]
def length : (@& String) → Nat
  | ⟨s⟩ => s.length

/--
Pushes a character onto the end of a string.

The internal implementation uses dynamic arrays and will perform destructive updates
if the string is not shared.

Example: `"abc".push 'd' = "abcd"`
-/
@[extern "lean_string_push"]
def push : String → Char → String
  | ⟨s⟩, c => ⟨s ++ [c]⟩

/--
Appends two strings.

The internal implementation uses dynamic arrays and will perform destructive updates
if the string is not shared.

Example: `"abc".append "def" = "abcdef"`
-/
@[extern "lean_string_append"]
def append : String → (@& String) → String
  | ⟨a⟩, ⟨b⟩ => ⟨a ++ b⟩

/--
Converts a string to a list of characters.

Even though the logical model of strings is as a structure that wraps a list of characters,
this operation takes time and space linear in the length of the string, because the compiler
uses an optimized representation as dynamic arrays.

Example: `"abc".toList = ['a', 'b', 'c']`
-/
def toList (s : String) : List Char :=
  s.data

/-- Returns true if `p` is a valid UTF-8 position in the string `s`, meaning that `p ≤ s.endPos`
and `p` lies on a UTF-8 character boundary. This has an O(1) implementation in the runtime. -/
@[extern "lean_string_is_valid_pos"]
def Pos.isValid (s : @&String) (p : @& Pos) : Bool :=
  go s.data 0
where
  go : List Char → Pos → Bool
  | [],    i => i = p
  | c::cs, i => if i = p then true else go cs (i + c)

def utf8GetAux : List Char → Pos → Pos → Char
  | [],    _, _ => default
  | c::cs, i, p => if i = p then c else utf8GetAux cs (i + c) p

/--
Returns the character at position `p` of a string. If `p` is not a valid position,
returns `(default : Char)`.

See `utf8GetAux` for the reference implementation.

Examples:
* `"abc".get ⟨1⟩ = 'b'`
* `"abc".get ⟨3⟩ = (default : Char) = 'A'`

Positions can also be invalid if a byte index points into the middle of a multi-byte UTF-8
character. For example,`"L∃∀N".get ⟨2⟩ = (default : Char) = 'A'`.
-/
@[extern "lean_string_utf8_get"]
def get (s : @& String) (p : @& Pos) : Char :=
  match s with
  | ⟨s⟩ => utf8GetAux s 0 p

def utf8GetAux? : List Char → Pos → Pos → Option Char
  | [],    _, _ => none
  | c::cs, i, p => if i = p then c else utf8GetAux? cs (i + c) p

/--
Returns the character at position `p`. If `p` is not a valid position, returns `none`.

Examples:
* `"abc".get? ⟨1⟩ = some 'b'`
* `"abc".get? ⟨3⟩ = none`

Positions can also be invalid if a byte index points into the middle of a multi-byte UTF-8
character. For example, `"L∃∀N".get? ⟨2⟩ = none`
-/
@[extern "lean_string_utf8_get_opt"]
def get? : (@& String) → (@& Pos) → Option Char
  | ⟨s⟩, p => utf8GetAux? s 0 p

/--
Returns the character at position `p` of a string. If `p` is not a valid position,
returns `(default : Char)` and produces a panic error message.

Examples:
* `"abc".get! ⟨1⟩ = 'b'`
* `"abc".get! ⟨3⟩` panics

Positions can also be invalid if a byte index points into the middle of a multi-byte UTF-8 character. For example,
`"L∃∀N".get! ⟨2⟩` panics.
-/
@[extern "lean_string_utf8_get_bang"]
def get! (s : @& String) (p : @& Pos) : Char :=
  match s with
  | ⟨s⟩ => utf8GetAux s 0 p

def utf8SetAux (c' : Char) : List Char → Pos → Pos → List Char
  | [],    _, _ => []
  | c::cs, i, p =>
    if i = p then (c'::cs) else c::(utf8SetAux c' cs (i + c) p)

/--
Replaces the character at a specified position in a string with a new character. If the position
is invalid, the string is returned unchanged.

If both the replacement character and the replaced character are ASCII characters and the string
is not shared, destructive updates are used.

Examples:
* `"abc".set ⟨1⟩ 'B' = "aBc"`
* `"abc".set ⟨3⟩ 'D' = "abc"`
* `"L∃∀N".set ⟨4⟩ 'X' = "L∃XN"`

Because `'∃'` is a multi-byte character, the byte index `2` in `L∃∀N` is an invalid position,
so `"L∃∀N".set ⟨2⟩ 'X' = "L∃∀N"`.
-/
@[extern "lean_string_utf8_set"]
def set : String → (@& Pos) → Char → String
  | ⟨s⟩, i, c => ⟨utf8SetAux c s 0 i⟩

/--
Replaces the character at position `p` in the string `s` with the result of applying `f` to that character.
If `p` is an invalid position, the string is returned unchanged.

Examples:
* `abc.modify ⟨1⟩ Char.toUpper = "aBc"`
* `abc.modify ⟨3⟩ Char.toUpper = "abc"`
-/
def modify (s : String) (i : Pos) (f : Char → Char) : String :=
  s.set i <| f <| s.get i

/--
Returns the next position in a string after position `p`. If `p` is not a valid position or `p = s.endPos`,
the result is unspecified.

Examples:
* `"abc".next ⟨1⟩ = String.Pos.mk 2`
* `"L∃∀N".next ⟨1⟩ = String.Pos.mk 4`, since `'∃'` is a multi-byte UTF-8 character

Cases where the result is unspecified:
* `"abc".next ⟨3⟩`, since `3 = s.endPos`
* `"L∃∀N".next ⟨2⟩`, since `2` points into the middle of a multi-byte UTF-8 character
-/
@[extern "lean_string_utf8_next"]
def next (s : @& String) (p : @& Pos) : Pos :=
  let c := get s p
  p + c

def utf8PrevAux : List Char → Pos → Pos → Pos
  | [],    _, _ => 0
  | c::cs, i, p =>
    let i' := i + c
    if i' = p then i else utf8PrevAux cs i' p

/--
Returns the position in a string before a specified position, `p`. If `p = ⟨0⟩`, returns `0`.
If `p` is not a valid position, the result is unspecified.

Examples:
* `"abc".prev ⟨2⟩ = String.Pos.mk 1`
* `"abc".prev ⟨0⟩ = String.Pos.mk 0`
* `"L∃∀N".prev ⟨4⟩ = String.Pos.mk 1`, since `'∃'` is a multi-byte UTF-8 character
-/
@[extern "lean_string_utf8_prev"]
def prev : (@& String) → (@& Pos) → Pos
  | ⟨s⟩, p => if p = 0 then 0 else utf8PrevAux s 0 p

/--
Returns the first character in `s`. If `s = ""`, returns `(default : Char)`.

Examples:
* `"abc".front = 'a'`
* `"".front = (default : Char)`
-/
def front (s : String) : Char :=
  get s 0

/--
Returns the last character in `s`. If `s = ""`, returns `(default : Char)`.

Examples:
* `"abc".back = 'c'`
* `"".back = (default : Char)`
-/
def back (s : String) : Char :=
  get s (prev s s.endPos)

/--
Returns `true` if a specified position is greater than or equal to the position which
points to the end of a string. Otherwise, returns `false`.

Examples:
Given `def abc := "abc"` and `def lean := "L∃∀N"`,
* `0 |> abc.next |> abc.next |> abc.atEnd = false`
* `0 |> abc.next |> abc.next |> abc.next |> abc.next |> abc.atEnd = true`
* `0 |> lean.next |> lean.next |> lean.next |> lean.next |> lean.atEnd = true`

Because "L∃∀N" contains multi-byte characters, `lean.next (lean.next 0)` is not equal to `abc.next (abc.next 0)`.
-/
@[extern "lean_string_utf8_at_end"]
def atEnd : (@& String) → (@& Pos) → Bool
  | s, p => p.byteIdx ≥ utf8ByteSize s

/--
Similar to `get` but runtime does not perform bounds check.
-/
@[extern "lean_string_utf8_get_fast"]
def get' (s : @& String) (p : @& Pos) (h : ¬ s.atEnd p) : Char :=
  match s with
  | ⟨s⟩ => utf8GetAux s 0 p

/--
Similar to `next` but runtime does not perform bounds check.
-/
@[extern "lean_string_utf8_next_fast"]
def next' (s : @& String) (p : @& Pos) (h : ¬ s.atEnd p) : Pos :=
  let c := get s p
  p + c

theorem one_le_csize (c : Char) : 1 ≤ csize c := by
  repeat first | apply iteInduction (motive := (1 ≤ UInt32.toNat ·)) <;> intros | decide

@[simp] theorem pos_lt_eq (p₁ p₂ : Pos) : (p₁ < p₂) = (p₁.1 < p₂.1) := rfl

@[simp] theorem pos_add_char (p : Pos) (c : Char) : (p + c).byteIdx = p.byteIdx + csize c := rfl

theorem lt_next (s : String) (i : Pos) : i.1 < (s.next i).1 :=
  Nat.add_lt_add_left (one_le_csize _) _

theorem utf8PrevAux_lt_of_pos : ∀ (cs : List Char) (i p : Pos), p ≠ 0 →
    (utf8PrevAux cs i p).1 < p.1
  | [], i, p, h =>
    Nat.lt_of_le_of_lt (Nat.zero_le _)
      (Nat.zero_lt_of_ne_zero (mt (congrArg Pos.mk) h))
  | c::cs, i, p, h => by
    simp [utf8PrevAux]
    apply iteInduction (motive := (Pos.byteIdx · < _)) <;> intro h'
    next => exact h' ▸ Nat.add_lt_add_left (one_le_csize _) _
    next => exact utf8PrevAux_lt_of_pos _ _ _ h

theorem prev_lt_of_pos (s : String) (i : Pos) (h : i ≠ 0) : (s.prev i).1 < i.1 := by
  simp [prev, h]
  exact utf8PrevAux_lt_of_pos _ _ _ h

def posOfAux (s : String) (c : Char) (stopPos : Pos) (pos : Pos) : Pos :=
  if h : pos < stopPos then
    if s.get pos == c then pos
    else
      have := Nat.sub_lt_sub_left h (lt_next s pos)
      posOfAux s c stopPos (s.next pos)
  else pos
termination_by stopPos.1 - pos.1

@[inline] def posOf (s : String) (c : Char) : Pos :=
  posOfAux s c s.endPos 0

def revPosOfAux (s : String) (c : Char) (pos : Pos) : Option Pos :=
  if h : pos = 0 then none
  else
    have := prev_lt_of_pos s pos h
    let pos := s.prev pos
    if s.get pos == c then some pos
    else revPosOfAux s c pos
termination_by pos.1

def revPosOf (s : String) (c : Char) : Option Pos :=
  revPosOfAux s c s.endPos

def findAux (s : String) (p : Char → Bool) (stopPos : Pos) (pos : Pos) : Pos :=
  if h : pos < stopPos then
    if p (s.get pos) then pos
    else
      have := Nat.sub_lt_sub_left h (lt_next s pos)
      findAux s p stopPos (s.next pos)
  else pos
termination_by stopPos.1 - pos.1

@[inline] def find (s : String) (p : Char → Bool) : Pos :=
  findAux s p s.endPos 0

def revFindAux (s : String) (p : Char → Bool) (pos : Pos) : Option Pos :=
  if h : pos = 0 then none
  else
    have := prev_lt_of_pos s pos h
    let pos := s.prev pos
    if p (s.get pos) then some pos
    else revFindAux s p pos
termination_by pos.1

def revFind (s : String) (p : Char → Bool) : Option Pos :=
  revFindAux s p s.endPos

abbrev Pos.min (p₁ p₂ : Pos) : Pos :=
  { byteIdx := p₁.byteIdx.min p₂.byteIdx }

/-- Returns the first position where the two strings differ. -/
def firstDiffPos (a b : String) : Pos :=
  let stopPos := a.endPos.min b.endPos
  let rec loop (i : Pos) : Pos :=
    if h : i < stopPos then
      if a.get i != b.get i then i
      else
        have := Nat.sub_lt_sub_left h (lt_next a i)
        loop (a.next i)
    else i
    termination_by stopPos.1 - i.1
  loop 0

@[extern "lean_string_utf8_extract"]
def extract : (@& String) → (@& Pos) → (@& Pos) → String
  | ⟨s⟩, b, e => if b.byteIdx ≥ e.byteIdx then "" else ⟨go₁ s 0 b e⟩
where
  go₁ : List Char → Pos → Pos → Pos → List Char
    | [],        _, _, _ => []
    | s@(c::cs), i, b, e => if i = b then go₂ s i e else go₁ cs (i + c) b e

  go₂ : List Char → Pos → Pos → List Char
    | [],    _, _ => []
    | c::cs, i, e => if i = e then [] else c :: go₂ cs (i + c) e


@[specialize] def splitAux (s : String) (p : Char → Bool) (b : Pos) (i : Pos) (r : List String) : List String :=
  if h : s.atEnd i then
    let r := (s.extract b i)::r
    r.reverse
  else
    have := Nat.sub_lt_sub_left (Nat.gt_of_not_le (mt decide_eq_true h)) (lt_next s _)
    if p (s.get i) then
      let i' := s.next i
      splitAux s p i' i' (s.extract b i :: r)
    else
      splitAux s p b (s.next i) r
termination_by s.endPos.1 - i.1

@[specialize] def split (s : String) (p : Char → Bool) : List String :=
  splitAux s p 0 0 []

/--
Auxiliary for `splitOn`. Preconditions:
* `sep` is not empty
* `b <= i` are indexes into `s`
* `j` is an index into `sep`, and not at the end

It represents the state where we have currently parsed some split parts into `r` (in reverse order),
`b` is the beginning of the string / the end of the previous match of `sep`, and the first `j` bytes
of `sep` match the bytes `i-j .. i` of `s`.
-/
def splitOnAux (s sep : String) (b : Pos) (i : Pos) (j : Pos) (r : List String) : List String :=
  if s.atEnd i then
    let r := (s.extract b i)::r
    r.reverse
  else
    if s.get i == sep.get j then
      let i := s.next i
      let j := sep.next j
      if sep.atEnd j then
        splitOnAux s sep i i 0 (s.extract b (i - j)::r)
      else
        splitOnAux s sep b i j r
    else
      splitOnAux s sep b (s.next (i - j)) 0 r
termination_by (s.endPos.1 - (i - j).1, sep.endPos.1 - j.1)
decreasing_by
  all_goals simp_wf
  focus
    rename_i h _ _
    left; exact Nat.sub_lt_sub_left
      (Nat.lt_of_le_of_lt (Nat.sub_le ..) (Nat.gt_of_not_le (mt decide_eq_true h)))
      (Nat.lt_of_le_of_lt (Nat.sub_le ..) (lt_next s _))
  focus
    rename_i i₀ j₀ _ eq h'
    rw [show (s.next i₀ - sep.next j₀).1 = (i₀ - j₀).1 by
      show (_ + csize _) - (_ + csize _) = _
      rw [(beq_iff_eq ..).1 eq, Nat.add_sub_add_right]; rfl]
    right; exact Nat.sub_lt_sub_left
      (Nat.lt_of_le_of_lt (Nat.le_add_right ..) (Nat.gt_of_not_le (mt decide_eq_true h')))
      (lt_next sep _)
  focus
    rename_i h _
    left; exact Nat.sub_lt_sub_left
      (Nat.lt_of_le_of_lt (Nat.sub_le ..) (Nat.gt_of_not_le (mt decide_eq_true h)))
      (lt_next s _)

/--
Splits a string `s` on occurrences of the separator `sep`. When `sep` is empty, it returns `[s]`;
when `sep` occurs in overlapping patterns, the first match is taken. There will always be exactly
`n+1` elements in the returned list if there were `n` nonoverlapping matches of `sep` in the string.
The default separator is `" "`. The separators are not included in the returned substrings.

```
"here is some text ".splitOn = ["here", "is", "some", "text", ""]
"here is some text ".splitOn "some" = ["here is ", " text "]
"here is some text ".splitOn "" = ["here is some text "]
"ababacabac".splitOn "aba" = ["", "bac", "c"]
```
-/
def splitOn (s : String) (sep : String := " ") : List String :=
  if sep == "" then [s] else splitOnAux s sep 0 0 0 []

instance : Inhabited String := ⟨""⟩

instance : Append String := ⟨String.append⟩

def str : String → Char → String := push

def pushn (s : String) (c : Char) (n : Nat) : String :=
  n.repeat (fun s => s.push c) s

def isEmpty (s : String) : Bool :=
  s.endPos == 0

def join (l : List String) : String :=
  l.foldl (fun r s => r ++ s) ""

def singleton (c : Char) : String :=
  "".push c

def intercalate (s : String) : List String → String
  | []      => ""
  | a :: as => go a s as
where go (acc : String) (s : String) : List String → String
  | a :: as => go (acc ++ s ++ a) s as
  | []      => acc

/-- Iterator over the characters (`Char`) of a `String`.

Typically created by `s.iter`, where `s` is a `String`.

An iterator is *valid* if the position `i` is *valid* for the string `s`, meaning `0 ≤ i ≤ s.endPos`
and `i` lies on a UTF8 byte boundary. If `i = s.endPos`, the iterator is at the end of the string.

Most operations on iterators return arbitrary values if the iterator is not valid. The functions in
the `String.Iterator` API should rule out the creation of invalid iterators, with two exceptions:

- `Iterator.next iter` is invalid if `iter` is already at the end of the string (`iter.atEnd` is
  `true`), and
- `Iterator.forward iter n`/`Iterator.nextn iter n` is invalid if `n` is strictly greater than the
  number of remaining characters.
-/
structure Iterator where
  /-- The string the iterator is for. -/
  s : String
  /-- The current position.

  This position is not necessarily valid for the string, for instance if one keeps calling
  `Iterator.next` when `Iterator.atEnd` is true. If the position is not valid, then the
  current character is `(default : Char)`, similar to `String.get` on an invalid position. -/
  i : Pos
  deriving DecidableEq

/-- Creates an iterator at the beginning of a string. -/
def mkIterator (s : String) : Iterator :=
  ⟨s, 0⟩

@[inherit_doc mkIterator]
abbrev iter := mkIterator

/-- The size of a string iterator is the number of bytes remaining. -/
instance : SizeOf String.Iterator where
  sizeOf i := i.1.utf8ByteSize - i.2.byteIdx

theorem Iterator.sizeOf_eq (i : String.Iterator) : sizeOf i = i.1.utf8ByteSize - i.2.byteIdx :=
  rfl

namespace Iterator
@[inherit_doc Iterator.s]
def toString := Iterator.s

/-- Number of bytes remaining in the iterator. -/
def remainingBytes : Iterator → Nat
  | ⟨s, i⟩ => s.endPos.byteIdx - i.byteIdx

@[inherit_doc Iterator.i]
def pos := Iterator.i

/-- The character at the current position.

On an invalid position, returns `(default : Char)`. -/
def curr : Iterator → Char
  | ⟨s, i⟩ => get s i

/-- Moves the iterator's position forward by one character, unconditionally.

It is only valid to call this function if the iterator is not at the end of the string, *i.e.*
`Iterator.atEnd` is `false`; otherwise, the resulting iterator will be invalid. -/
def next : Iterator → Iterator
  | ⟨s, i⟩ => ⟨s, s.next i⟩

/-- Decreases the iterator's position.

If the position is zero, this function is the identity. -/
def prev : Iterator → Iterator
  | ⟨s, i⟩ => ⟨s, s.prev i⟩

/-- True if the iterator is past the string's last character. -/
def atEnd : Iterator → Bool
  | ⟨s, i⟩ => i.byteIdx ≥ s.endPos.byteIdx

/-- True if the iterator is not past the string's last character. -/
def hasNext : Iterator → Bool
  | ⟨s, i⟩ => i.byteIdx < s.endPos.byteIdx

/-- True if the position is not zero. -/
def hasPrev : Iterator → Bool
  | ⟨_, i⟩ => i.byteIdx > 0

/-- Replaces the current character in the string.

Does nothing if the iterator is at the end of the string. If the iterator contains the only
reference to its string, this function will mutate the string in-place instead of allocating a new
one. -/
def setCurr : Iterator → Char → Iterator
  | ⟨s, i⟩, c => ⟨s.set i c, i⟩

/-- Moves the iterator's position to the end of the string.

Note that `i.toEnd.atEnd` is always `true`. -/
def toEnd : Iterator → Iterator
  | ⟨s, _⟩ => ⟨s, s.endPos⟩

/-- Extracts the substring between the positions of two iterators.

Returns the empty string if the iterators are for different strings, or if the position of the first
iterator is past the position of the second iterator. -/
def extract : Iterator → Iterator → String
  | ⟨s₁, b⟩, ⟨s₂, e⟩ =>
    if s₁ ≠ s₂ || b > e then ""
    else s₁.extract b e

/-- Moves the iterator's position several characters forward.

The resulting iterator is only valid if the number of characters to skip is less than or equal to
the number of characters left in the iterator. -/
def forward : Iterator → Nat → Iterator
  | it, 0   => it
  | it, n+1 => forward it.next n

/-- The remaining characters in an iterator, as a string. -/
def remainingToString : Iterator → String
  | ⟨s, i⟩ => s.extract i s.endPos

@[inherit_doc forward]
def nextn : Iterator → Nat → Iterator
  | it, 0   => it
  | it, i+1 => nextn it.next i

/-- Moves the iterator's position several characters back.

If asked to go back more characters than available, stops at the beginning of the string. -/
def prevn : Iterator → Nat → Iterator
  | it, 0   => it
  | it, i+1 => prevn it.prev i
end Iterator

def offsetOfPosAux (s : String) (pos : Pos) (i : Pos) (offset : Nat) : Nat :=
  if i >= pos then offset
  else if h : s.atEnd i then
    offset
  else
    have := Nat.sub_lt_sub_left (Nat.gt_of_not_le (mt decide_eq_true h)) (lt_next s _)
    offsetOfPosAux s pos (s.next i) (offset+1)
termination_by s.endPos.1 - i.1

def offsetOfPos (s : String) (pos : Pos) : Nat :=
  offsetOfPosAux s pos 0 0

@[specialize] def foldlAux {α : Type u} (f : α → Char → α) (s : String) (stopPos : Pos) (i : Pos) (a : α) : α :=
  if h : i < stopPos then
    have := Nat.sub_lt_sub_left h (lt_next s i)
    foldlAux f s stopPos (s.next i) (f a (s.get i))
  else a
termination_by stopPos.1 - i.1

@[inline] def foldl {α : Type u} (f : α → Char → α) (init : α) (s : String) : α :=
  foldlAux f s s.endPos 0 init

@[specialize] def foldrAux {α : Type u} (f : Char → α → α) (a : α) (s : String) (i begPos : Pos) : α :=
  if h : begPos < i then
    have := String.prev_lt_of_pos s i <| mt (congrArg String.Pos.byteIdx) <|
      Ne.symm <| Nat.ne_of_lt <| Nat.lt_of_le_of_lt (Nat.zero_le _) h
    let i := s.prev i
    let a := f (s.get i) a
    foldrAux f a s i begPos
  else a
termination_by i.1

@[inline] def foldr {α : Type u} (f : Char → α → α) (init : α) (s : String) : α :=
  foldrAux f init s s.endPos 0

@[specialize] def anyAux (s : String) (stopPos : Pos) (p : Char → Bool) (i : Pos) : Bool :=
  if h : i < stopPos then
    if p (s.get i) then true
    else
      have := Nat.sub_lt_sub_left h (lt_next s i)
      anyAux s stopPos p (s.next i)
  else false
termination_by stopPos.1 - i.1

@[inline] def any (s : String) (p : Char → Bool) : Bool :=
  anyAux s s.endPos p 0

@[inline] def all (s : String) (p : Char → Bool) : Bool :=
  !s.any (fun c => !p c)

def contains (s : String) (c : Char) : Bool :=
s.any (fun a => a == c)

theorem utf8SetAux_of_gt (c' : Char) : ∀ (cs : List Char) {i p : Pos}, i > p → utf8SetAux c' cs i p = cs
  | [],    _, _, _ => rfl
  | c::cs, i, p, h => by
    rw [utf8SetAux, if_neg (mt (congrArg (·.1)) (Ne.symm <| Nat.ne_of_lt h)), utf8SetAux_of_gt c' cs]
    exact Nat.lt_of_lt_of_le h (Nat.le_add_right ..)

theorem set_next_add (s : String) (i : Pos) (c : Char) (b₁ b₂)
    (h : (s.next i).1 + b₁ = s.endPos.1 + b₂) :
    ((s.set i c).next i).1 + b₁ = (s.set i c).endPos.1 + b₂ := by
  simp [next, get, set, endPos, utf8ByteSize] at h ⊢
  rw [Nat.add_comm i.1, Nat.add_assoc] at h ⊢
  let rec foo : ∀ cs a b₁ b₂,
    csize (utf8GetAux cs a i) + b₁ = utf8ByteSize.go cs + b₂ →
    csize (utf8GetAux (utf8SetAux c cs a i) a i) + b₁ = utf8ByteSize.go (utf8SetAux c cs a i) + b₂
  | [], _, _, _, h => h
  | c'::cs, a, b₁, b₂, h => by
    unfold utf8SetAux
    apply iteInduction (motive := fun p => csize (utf8GetAux p a i) + b₁ = utf8ByteSize.go p + b₂) <;>
      intro h' <;> simp [utf8GetAux, h', utf8ByteSize.go] at h ⊢
    next =>
      rw [Nat.add_assoc, Nat.add_left_comm] at h ⊢; rw [Nat.add_left_cancel h]
    next =>
      rw [Nat.add_assoc] at h ⊢
      refine foo cs (a + c') b₁ (csize c' + b₂) h
  exact foo s.1 0 _ _ h

theorem mapAux_lemma (s : String) (i : Pos) (c : Char) (h : ¬s.atEnd i) :
    (s.set i c).endPos.1 - ((s.set i c).next i).1 < s.endPos.1 - i.1 :=
  suffices (s.set i c).endPos.1 - ((s.set i c).next i).1 = s.endPos.1 - (s.next i).1 by
    rw [this]
    apply Nat.sub_lt_sub_left (Nat.gt_of_not_le (mt decide_eq_true h)) (lt_next ..)
  Nat.sub.elim (motive := (_ = ·)) _ _
    (fun _ k e =>
      have := set_next_add _ _ _ k 0 e.symm
      Nat.sub_eq_of_eq_add <| this.symm.trans <| Nat.add_comm ..)
    (fun h => by
      have ⟨k, e⟩ := Nat.le.dest h
      rw [Nat.succ_add] at e
      have : ((s.set i c).next i).1 = _ := set_next_add _ _ c 0 k.succ e.symm
      exact Nat.sub_eq_zero_of_le (this ▸ Nat.le_add_right ..))

@[specialize] def mapAux (f : Char → Char) (i : Pos) (s : String) : String :=
  if h : s.atEnd i then s
  else
    let c := f (s.get i)
    have := mapAux_lemma s i c h
    let s := s.set i c
    mapAux f (s.next i) s
termination_by s.endPos.1 - i.1

@[inline] def map (f : Char → Char) (s : String) : String :=
  mapAux f 0 s

def isNat (s : String) : Bool :=
  !s.isEmpty && s.all (·.isDigit)

def toNat? (s : String) : Option Nat :=
  if s.isNat then
    some <| s.foldl (fun n c => n*10 + (c.toNat - '0'.toNat)) 0
  else
    none

/--
Return `true` iff the substring of byte size `sz` starting at position `off1` in `s1` is equal to that starting at `off2` in `s2.`.
False if either substring of that byte size does not exist. -/
def substrEq (s1 : String) (off1 : String.Pos) (s2 : String) (off2 : String.Pos) (sz : Nat) : Bool :=
  off1.byteIdx + sz ≤ s1.endPos.byteIdx && off2.byteIdx + sz ≤ s2.endPos.byteIdx && loop off1 off2 { byteIdx := off1.byteIdx + sz }
where
  loop (off1 off2 stop1 : Pos) :=
    if _h : off1.byteIdx < stop1.byteIdx then
      let c₁ := s1.get off1
      let c₂ := s2.get off2
      c₁ == c₂ && loop (off1 + c₁) (off2 + c₂) stop1
    else true
  termination_by stop1.1 - off1.1
  decreasing_by
    have := Nat.sub_lt_sub_left _h (Nat.add_lt_add_left (one_le_csize c₁) off1.1)
    decreasing_tactic

/-- Return true iff `p` is a prefix of `s` -/
def isPrefixOf (p : String) (s : String) : Bool :=
  substrEq p 0 s 0 p.endPos.byteIdx

/-- Replace all occurrences of `pattern` in `s` with `replacement`. -/
def replace (s pattern replacement : String) : String :=
  if h : pattern.endPos.1 = 0 then s
  else
    have hPatt := Nat.zero_lt_of_ne_zero h
    let rec loop (acc : String) (accStop pos : String.Pos) :=
      if h : pos.byteIdx + pattern.endPos.byteIdx > s.endPos.byteIdx then
        acc ++ s.extract accStop s.endPos
      else
        have := Nat.lt_of_lt_of_le (Nat.add_lt_add_left hPatt _) (Nat.ge_of_not_lt h)
        if s.substrEq pos pattern 0 pattern.endPos.byteIdx then
          have := Nat.sub_lt_sub_left this (Nat.add_lt_add_left hPatt _)
          loop (acc ++ s.extract accStop pos ++ replacement) (pos + pattern) (pos + pattern)
        else
          have := Nat.sub_lt_sub_left this (lt_next s pos)
          loop acc accStop (s.next pos)
      termination_by s.endPos.1 - pos.1
    loop "" 0 0

/-- Return the beginning of the line that contains character `pos`. -/
def findLineStart (s : String) (pos : String.Pos) : String.Pos :=
  match s.revFindAux (· = '\n') pos with
  | none => 0
  | some n => ⟨n.byteIdx + 1⟩

end String

namespace Substring

@[inline] def isEmpty (ss : Substring) : Bool :=
  ss.bsize == 0

@[inline] def toString : Substring → String
  | ⟨s, b, e⟩ => s.extract b e

@[inline] def toIterator : Substring → String.Iterator
  | ⟨s, b, _⟩ => ⟨s, b⟩

/-- Return the codepoint at the given offset into the substring. -/
@[inline] def get : Substring → String.Pos → Char
  | ⟨s, b, _⟩, p => s.get (b+p)

/-- Given an offset of a codepoint into the substring,
return the offset there of the next codepoint. -/
@[inline] def next : Substring → String.Pos → String.Pos
  | ⟨s, b, e⟩, p =>
    let absP := b+p
    if absP = e then p else { byteIdx := (s.next absP).byteIdx - b.byteIdx }

theorem lt_next (s : Substring) (i : String.Pos) (h : i.1 < s.bsize) :
    i.1 < (s.next i).1 := by
  simp [next]; rw [if_neg ?a]
  case a =>
    refine mt (congrArg String.Pos.byteIdx) (Nat.ne_of_lt ?_)
    exact (Nat.add_comm .. ▸ Nat.add_lt_of_lt_sub h :)
  apply Nat.lt_sub_of_add_lt
  rw [Nat.add_comm]; apply String.lt_next

/-- Given an offset of a codepoint into the substring,
return the offset there of the previous codepoint. -/
@[inline] def prev : Substring → String.Pos → String.Pos
  | ⟨s, b, _⟩, p =>
    let absP := b+p
    if absP = b then p else { byteIdx := (s.prev absP).byteIdx - b.byteIdx }

def nextn : Substring → Nat → String.Pos → String.Pos
  | _,  0,   p => p
  | ss, i+1, p => ss.nextn i (ss.next p)

def prevn : Substring → Nat → String.Pos → String.Pos
  | _,  0,   p => p
  | ss, i+1, p => ss.prevn i (ss.prev p)

@[inline] def front (s : Substring) : Char :=
  s.get 0

/-- Return the offset into `s` of the first occurrence of `c` in `s`,
or `s.bsize` if `c` doesn't occur. -/
@[inline] def posOf (s : Substring) (c : Char) : String.Pos :=
  match s with
  | ⟨s, b, e⟩ => { byteIdx := (String.posOfAux s c e b).byteIdx - b.byteIdx }

@[inline] def drop : Substring → Nat → Substring
  | ss@⟨s, b, e⟩, n => ⟨s, b + ss.nextn n 0, e⟩

@[inline] def dropRight : Substring → Nat → Substring
  | ss@⟨s, b, _⟩, n => ⟨s, b, b + ss.prevn n ⟨ss.bsize⟩⟩

@[inline] def take : Substring → Nat → Substring
  | ss@⟨s, b, _⟩, n => ⟨s, b, b + ss.nextn n 0⟩

@[inline] def takeRight : Substring → Nat → Substring
  | ss@⟨s, b, e⟩, n => ⟨s, b + ss.prevn n ⟨ss.bsize⟩, e⟩

@[inline] def atEnd : Substring → String.Pos → Bool
  | ⟨_, b, e⟩, p => b + p == e

@[inline] def extract : Substring → String.Pos → String.Pos → Substring
  | ⟨s, b, e⟩, b', e' => if b' ≥ e' then ⟨"", 0, 0⟩ else ⟨s, e.min (b+b'), e.min (b+e')⟩

def splitOn (s : Substring) (sep : String := " ") : List Substring :=
  if sep == "" then
    [s]
  else
    let rec loop (b i j : String.Pos) (r : List Substring) : List Substring :=
      if h : i.byteIdx < s.bsize then
        have := Nat.sub_lt_sub_left h (lt_next s i h)
        if s.get i == sep.get j then
          let i := s.next i
          let j := sep.next j
          if sep.atEnd j then
            loop i i 0 (s.extract b (i-j) :: r)
          else
            loop b i j r
        else
          loop b (s.next i) 0 r
      else
        let r := if sep.atEnd j then
          "".toSubstring :: s.extract b (i-j) :: r
        else
          s.extract b i :: r
        r.reverse
      termination_by s.bsize - i.1
    loop 0 0 0 []

@[inline] def foldl {α : Type u} (f : α → Char → α) (init : α) (s : Substring) : α :=
  match s with
  | ⟨s, b, e⟩ => String.foldlAux f s e b init

@[inline] def foldr {α : Type u} (f : Char → α → α) (init : α) (s : Substring) : α :=
  match s with
  | ⟨s, b, e⟩ => String.foldrAux f init s e b

@[inline] def any (s : Substring) (p : Char → Bool) : Bool :=
  match s with
  | ⟨s, b, e⟩ => String.anyAux s e p b

@[inline] def all (s : Substring) (p : Char → Bool) : Bool :=
  !s.any (fun c => !p c)

def contains (s : Substring) (c : Char) : Bool :=
  s.any (fun a => a == c)

@[specialize] def takeWhileAux (s : String) (stopPos : String.Pos) (p : Char → Bool) (i : String.Pos) : String.Pos :=
  if h : i < stopPos then
    if p (s.get i) then
      have := Nat.sub_lt_sub_left h (String.lt_next s i)
      takeWhileAux s stopPos p (s.next i)
    else i
  else i
termination_by stopPos.1 - i.1

@[inline] def takeWhile : Substring → (Char → Bool) → Substring
  | ⟨s, b, e⟩, p =>
    let e := takeWhileAux s e p b;
    ⟨s, b, e⟩

@[inline] def dropWhile : Substring → (Char → Bool) → Substring
  | ⟨s, b, e⟩, p =>
    let b := takeWhileAux s e p b;
    ⟨s, b, e⟩

@[specialize] def takeRightWhileAux (s : String) (begPos : String.Pos) (p : Char → Bool) (i : String.Pos) : String.Pos :=
  if h : begPos < i then
    have := String.prev_lt_of_pos s i <| mt (congrArg String.Pos.byteIdx) <|
      Ne.symm <| Nat.ne_of_lt <| Nat.lt_of_le_of_lt (Nat.zero_le _) h
    let i' := s.prev i
    let c  := s.get i'
    if !p c then i
    else takeRightWhileAux s begPos p i'
  else i
termination_by i.1

@[inline] def takeRightWhile : Substring → (Char → Bool) → Substring
  | ⟨s, b, e⟩, p =>
    let b := takeRightWhileAux s b p e
    ⟨s, b, e⟩

@[inline] def dropRightWhile : Substring → (Char → Bool) → Substring
  | ⟨s, b, e⟩, p =>
    let e := takeRightWhileAux s b p e
    ⟨s, b, e⟩

@[inline] def trimLeft (s : Substring) : Substring :=
  s.dropWhile Char.isWhitespace

@[inline] def trimRight (s : Substring) : Substring :=
  s.dropRightWhile Char.isWhitespace

@[inline] def trim : Substring → Substring
  | ⟨s, b, e⟩ =>
    let b := takeWhileAux s e Char.isWhitespace b
    let e := takeRightWhileAux s b Char.isWhitespace e
    ⟨s, b, e⟩

def isNat (s : Substring) : Bool :=
  s.all fun c => c.isDigit

def toNat? (s : Substring) : Option Nat :=
  if s.isNat then
    some <| s.foldl (fun n c => n*10 + (c.toNat - '0'.toNat)) 0
  else
    none

def beq (ss1 ss2 : Substring) : Bool :=
  ss1.bsize == ss2.bsize && ss1.str.substrEq ss1.startPos ss2.str ss2.startPos ss1.bsize

instance hasBeq : BEq Substring := ⟨beq⟩

end Substring

namespace String

def drop (s : String) (n : Nat) : String :=
  (s.toSubstring.drop n).toString

def dropRight (s : String) (n : Nat) : String :=
  (s.toSubstring.dropRight n).toString

def take (s : String) (n : Nat) : String :=
  (s.toSubstring.take n).toString

def takeRight (s : String) (n : Nat) : String :=
  (s.toSubstring.takeRight n).toString

def takeWhile (s : String) (p : Char → Bool) : String :=
  (s.toSubstring.takeWhile p).toString

def dropWhile (s : String) (p : Char → Bool) : String :=
  (s.toSubstring.dropWhile p).toString

def takeRightWhile (s : String) (p : Char → Bool) : String :=
  (s.toSubstring.takeRightWhile p).toString

def dropRightWhile (s : String) (p : Char → Bool) : String :=
  (s.toSubstring.dropRightWhile p).toString

def startsWith (s pre : String) : Bool :=
  s.toSubstring.take pre.length == pre.toSubstring

def endsWith (s post : String) : Bool :=
  s.toSubstring.takeRight post.length == post.toSubstring

def trimRight (s : String) : String :=
  s.toSubstring.trimRight.toString

def trimLeft (s : String) : String :=
  s.toSubstring.trimLeft.toString

def trim (s : String) : String :=
  s.toSubstring.trim.toString

@[inline] def nextWhile (s : String) (p : Char → Bool) (i : String.Pos) : String.Pos :=
  Substring.takeWhileAux s s.endPos p i

@[inline] def nextUntil (s : String) (p : Char → Bool) (i : String.Pos) : String.Pos :=
  nextWhile s (fun c => !p c) i

def toUpper (s : String) : String :=
  s.map Char.toUpper

def toLower (s : String) : String :=
  s.map Char.toLower

def capitalize (s : String) :=
  s.set 0 <| s.get 0 |>.toUpper

def decapitalize (s : String) :=
  s.set 0 <| s.get 0 |>.toLower

end String

protected def Char.toString (c : Char) : String :=
  String.singleton c
