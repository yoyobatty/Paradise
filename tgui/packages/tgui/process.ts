import { Marked } from 'marked';
import { baseUrl } from 'marked-base-url';
import { markedSmartypants } from 'marked-smartypants';

import { sanitizeText } from './sanitize';

const markdown = new Marked(markedSmartypants(), baseUrl('thisshouldbreakhttp'));

export const processedText = (value) => {
  const textHtml = {
    __html: sanitizeText(markdown.parse(value, { breaks: true, async: false })),
  };
  return textHtml;
};
