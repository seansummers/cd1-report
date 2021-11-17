"""Integer range tools."""
import itertools

from typing import Iterable


def extract(lst: Iterable[int]) -> str:
    """create string integer sets from list
    >>> extract([4,5,7,8,-6,-3,-2,3,4,5,9,10,20])
    '-6,-3--2,3-5,7-10,20'
    >>> extract([1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14])
    '1-6,8-12,14'
    >>> extract([8, 17, 18, 19, 21, 22, 23, 24])
    '8,17-19,21-24'
    >>> extract([8, 17, 18, 19, 21, 22, 23, 24, 99])
    '8,17-19,21-24,99'
    """

    def list_to_groups(lst: Iterable[int]) -> Iterable[str]:
        """generate string integer sets from a list of integers
        >>> tuple(list_to_groups([-3,2,5,6,-4]))
        ('-4--3', '2', '5-6')
        """
        a, b = itertools.tee(sorted(set(lst)))
        next(b, None)
        i = itertools.zip_longest(a, b, fillvalue=0)
        for x, y in i:
            start = stop = x
            while y - x == 1:
                stop = y
                x, y = next(i, (0, 0))
            yield ("{}" if start == stop else "{}-{}").format(start, stop)

    return ",".join(list_to_groups(lst))


def expand(txt: str) -> Iterable[int]:
    """parse string of integer sets with intervals to list
    Handles arbitrary whitespace, overlapping ranges, out-of-order ranges,
    and negative integers.
    >>> expand("-6,-3--1,3-5,7-11,14,15,17-20")
    [-6, -3, -2, -1, 3, 4, 5, 7, 8, 9, 10, 11, 14, 15, 17, 18, 19, 20]
    >>> expand("1-4,6,3-2, 11, 8 - 12,5,14-14")
    [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14]
    >>> expand("1-4,6,3-2, 11, 8 - 12,5,14-14")
    [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14]
    >>> expand('8,17-19,21-24')
    [8, 17, 18, 19, 21, 22, 23, 24]
    >>> expand('8,17-19,21-24,99')
    [8, 17, 18, 19, 21, 22, 23, 24, 99]
    """

    def range_expand(group: str) -> Iterable[int]:
        """parse single string integer set to list
        Handles arbitrary whitespace, out-of-order
        and negative integers.
        >>> range_expand("-3--1")
        [-3, -2, -1]
        >>> range_expand("3-2")
        [2, 3]
        >>> range_expand(" 3 -  - 2 ")
        [-2, -1, 0, 1, 2, 3]
        """

        group = "".join(group.split())
        sign, g = ("-", group[1:]) if group.startswith("-") else ("", group)
        r = g.split("-", 1)
        r[0] = "".join((sign, r[0]))
        r = sorted(int(__) for __ in r)
        return range(r[0], 1 + r[-1])

    ranges = itertools.chain.from_iterable(range_expand(__) for __ in txt.split(","))
    return sorted(set(ranges))

if __name__ == '__main__':
    import doctest
    doctest.testmod()

