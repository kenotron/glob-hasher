/* tslint:disable */
/* eslint-disable */

/* auto-generated by NAPI-RS */

export interface PartialHashGlobOptions {
  cwd?: string
  gitignore?: boolean
}
export function hashGlobParallel(globs: Array<string>, maybeOptions?: PartialHashGlobOptions | undefined | null): Record<string, bigint> | null
export function hashGlob(globs: Array<string>, maybeOptions?: PartialHashGlobOptions | undefined | null): Record<string, bigint> | null
