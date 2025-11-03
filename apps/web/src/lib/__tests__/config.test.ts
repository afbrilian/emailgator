import { API_URL, getApiUrl } from '../config'

describe('config', () => {
  it('exports API_URL', () => {
    expect(API_URL).toBeDefined()
    expect(typeof API_URL).toBe('string')
  })

  it('getApiUrl constructs URL with path', () => {
    const result = getApiUrl('/test/path')
    expect(result).toBe(`${API_URL}/test/path`)
  })

  it('getApiUrl handles path without leading slash', () => {
    const result = getApiUrl('test/path')
    expect(result).toBe(`${API_URL}/test/path`)
  })
})
